class ApplicationController < ActionController::API
  include Pundit::Authorization

  respond_to :json

  before_action :authenticate_user!
  after_action :verify_authorized, unless: :skip_authorization?
  after_action :ensure_policy_scope, unless: :skip_policy_scope?

  rescue_from Pundit::NotAuthorizedError do |exception|
    render_error(
      code: "not_authorized",
      message: "You are not authorized to perform this action.",
      status: :forbidden
    )
  end

  rescue_from ApplicationPolicy::NotAuthenticatedError do
    render_error(
      code: "unauthenticated",
      message: "You need to sign in before continuing.",
      status: :unauthorized
    )
  end

  private

  def current_user
    @current_user
  end

  def pundit_user
    current_user
  end

  def skip_authorization?
    devise_controller? || auth_namespace_controller?
  end

  def skip_policy_scope?
    devise_controller? || auth_namespace_controller?
  end

  def ensure_policy_scope
    return unless policy_scope_action?

    verify_policy_scoped
  end

  def policy_scope_action?
    action_name == "index"
  end

  def auth_namespace_controller?
    self.class.name.start_with?("Auth::")
  end

  def authenticate_user!
  @current_user = nil
  token = bearer_token

    if token.blank?
      render_error(
        code: "unauthenticated",
        message: "Authorization header is missing or invalid.",
        status: :unauthorized
      )
      return
    end

    payload = JwtTokenService.decode!(token)

    unless payload[:typ] == "access"
      render_error(
        code: "invalid_token",
        message: "Access token is required for this request.",
        status: :unauthorized
      )
      return
    end

    user = User.find_by(id: payload[:sub])

    if user.nil?
      render_error(
        code: "invalid_token",
        message: "The provided token is no longer valid.",
        status: :unauthorized
      )
      return
    end

    @current_user = user
  rescue JwtTokenService::TokenExpiredError
    render_error(
      code: "token_expired",
      message: "Access token has expired.",
      status: :unauthorized
    )
  rescue JwtTokenService::TokenDecodeError
    render_error(
      code: "invalid_token",
      message: "Access token could not be decoded.",
      status: :unauthorized
    )
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    return if header.blank?

    scheme, token = header.split(" ", 2)
    return token if scheme.casecmp("bearer").zero?

    nil
  end

  def render_error(code:, message:, status:)
    render json: { error: { code:, message: } }, status: status
  end

  def render_validation_errors(record)
    errors =
      record
        .errors
        .map do |error|
          { field: error.attribute, message: error.message }
        end

    render json: { errors: }, status: :unprocessable_content
  end
end
