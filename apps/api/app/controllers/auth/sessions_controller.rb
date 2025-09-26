require "securerandom"

module Auth
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user!, raise: false

    def create
      user = find_user

      if user.nil?
        AuditLogger.log(
          event: "auth.sign_in.failed",
          ip: request.remote_ip,
          metadata: { email: sign_in_params[:email].to_s.strip.downcase }
        )
        render_invalid_credentials and return
      end

      authenticated = user.valid_for_authentication? do
        user.valid_password?(sign_in_params[:password])
      end

      unless authenticated
        AuditLogger.log(
          event: "auth.sign_in.failed",
          user:,
          ip: request.remote_ip,
          metadata: { locked: user.access_locked? }
        )

        if user.access_locked?
          render_error(
            code: "account_locked",
            message: "Account is locked due to too many failed attempts.",
            status: :locked
          )
        else
          render_invalid_credentials
        end

        return
      end

      user.after_database_authentication

      issued_at = Time.current
      access_jti = SecureRandom.uuid
      refresh_jti = SecureRandom.uuid
      access_token = JwtTokenService.issue_access_token(user, jti: access_jti, issued_at:)
      refresh_token = JwtTokenService.issue_refresh_token(user, jti: refresh_jti, issued_at:)

      user.refresh_tokens.active.update_all(revoked_at: issued_at)

      user.refresh_tokens.create!(
        token_digest: RefreshToken.digest(refresh_token),
        jti: refresh_jti,
        expires_at: issued_at + JwtTokenService.refresh_token_expires_in
      )

      AuditLogger.log(event: "auth.sign_in.success", user:, ip: request.remote_ip)

      render json: {
               accessToken: access_token,
               refreshToken: refresh_token,
               user: serialize_user(user)
             },
             status: :ok
    end

    def destroy
      raw_refresh = params.require(:refreshToken)
      payload = JwtTokenService.decode!(raw_refresh)

      unless payload[:typ] == "refresh"
        render_invalid_refresh and return
      end

      token = RefreshToken.find_by(token_digest: RefreshToken.digest(raw_refresh))
      payload_sub = payload[:sub].to_i

      if token.nil? || token.revoked? || token.user_id != payload_sub
        render_invalid_refresh and return
      end

      token.revoke!

      AuditLogger.log(event: "auth.sign_out", user: token.user, ip: request.remote_ip)

      render json: { success: true }, status: :ok
    rescue ActionController::ParameterMissing
      render_error(
        code: "invalid_refresh_token",
        message: "refreshToken is required",
        status: :unprocessable_content
      )
    rescue JwtTokenService::TokenExpiredError
      render_invalid_refresh("Refresh token has expired")
    rescue JwtTokenService::TokenDecodeError
      render_invalid_refresh
    end

    private

    def find_user
      email = sign_in_params[:email]&.strip&.downcase
      return if email.blank?

      User.find_for_database_authentication(email:)
    end

    def sign_in_params
      params.permit(:email, :password)
    end

    def serialize_user(user)
      { id: user.id, email: user.email, role: user.role }
    end

    def render_invalid_credentials
      render_error(
        code: "invalid_credentials",
        message: "Invalid email or password.",
        status: :unauthorized
      )
    end

    def render_invalid_refresh(message = "Refresh token is invalid.")
      render_error(code: "invalid_refresh_token", message:, status: :unauthorized)
    end
  end
end
