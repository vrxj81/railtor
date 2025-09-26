module Auth
  class RegistrationsController < ApplicationController
    def create
      user = User.new(sign_up_params)
      user.role = :customer
      user.skip_confirmation!

      if user.save
        render json: serialize_user(user), status: :created
      else
        render_validation_errors(user)
      end
    end

    private

    def sign_up_params
      params.permit(:email, :password)
    end

    def serialize_user(user)
      { id: user.id, email: user.email, role: user.role }
    end
  end
end
