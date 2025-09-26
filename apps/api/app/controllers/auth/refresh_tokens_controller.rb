require "securerandom"

module Auth
  class RefreshTokensController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

    def create
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

      user = token.user
      issued_at = Time.current
      new_tokens = nil

      RefreshToken.transaction do
        token.revoke!
        new_tokens = issue_rotated_tokens(user:, issued_at:)
      end

      render json: new_tokens, status: :ok
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

    def issue_rotated_tokens(user:, issued_at:)
      access_jti = SecureRandom.uuid
      refresh_jti = SecureRandom.uuid

      access_token =
        JwtTokenService.issue_access_token(user, jti: access_jti, issued_at:)
      refresh_token =
        JwtTokenService.issue_refresh_token(user, jti: refresh_jti, issued_at:)

      user.refresh_tokens.create!(
        token_digest: RefreshToken.digest(refresh_token),
        jti: refresh_jti,
        expires_at: issued_at + JwtTokenService.refresh_token_expires_in
      )

      {
        accessToken: access_token,
        refreshToken: refresh_token,
        user: { id: user.id, email: user.email, role: user.role }
      }
    end

    def render_invalid_refresh(message = "Refresh token is invalid.")
      render_error(code: "invalid_refresh_token", message:, status: :unauthorized)
    end
  end
end
