class ApplicationController < ActionController::API
  respond_to :json

  private

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
