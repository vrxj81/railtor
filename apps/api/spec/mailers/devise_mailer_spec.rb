require "rails_helper"

RSpec.describe Devise::Mailer, type: :mailer do
  describe "reset_password_instructions" do
    it "renders a link to the web application reset screen" do
      user = User.create!(
        email: "mailer@example.com",
        password: "Supersafe01!",
        confirmed_at: Time.current,
        role: :customer
      )

      token = "test-token"
      mail = described_class.reset_password_instructions(user, token)

      reset_link =
        "#{Rails.application.config.x.web_app_url}/reset-password?token=#{token}"

      expect(mail.subject).to include("Reset password instructions")
      expect(mail.body.encoded).to include(reset_link)
    end
  end
end
