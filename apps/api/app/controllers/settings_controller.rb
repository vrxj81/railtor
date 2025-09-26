class SettingsController < ApplicationController
  def show
    authorize :settings, :show?

    render json: {
      application: {
        name: "Railtor",
        version: Rails.application.config.x.application_version || "0.0.1"
      },
      features: {
        authentication: true,
        password_reset: true
      }
    }
  end
end
