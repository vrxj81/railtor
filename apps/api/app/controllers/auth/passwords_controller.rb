module Auth
  class PasswordsController < ApplicationController
    def forgot
      email = params[:email].to_s.strip.downcase

      if email.present?
        user = User.find_by(email: email)
        user&.send_reset_password_instructions
      end

      render json: { success: true }, status: :ok
    end

    def reset
      token = params.require(:token)
      password = params.require(:password)

      user =
        User.reset_password_by_token(
          reset_password_token: token,
          password: password
        )

      if user.errors[:reset_password_token].present?
        render_invalid_or_expired_token and return
      end

      if user.errors.any?
        render_validation_errors(user)
        return
      end

      user.unlock_access! if user.respond_to?(:unlock_access!) && user.access_locked?

      render json: { success: true }, status: :ok
    rescue ActionController::ParameterMissing => e
      render_error(
        code: "invalid_request",
        message: e.message,
        status: :unprocessable_content
      )
    end

    private

    def render_invalid_or_expired_token
      render_error(
        code: "invalid_or_expired_token",
        message: "Reset token is invalid or has expired.",
        status: :bad_request
      )
    end
  end
end
