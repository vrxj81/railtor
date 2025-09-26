require "rails_helper"

RSpec.describe "Password reset API", type: :request do
  let(:headers) { { "CONTENT_TYPE" => "application/json" } }
  let(:password) { "Supersafe01!" }

  before do
    ActionMailer::Base.deliveries.clear
  end

  describe "POST /auth/password/forgot" do
    let!(:user) do
      User.create!(
        email: "forgot@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )
    end

    it "sends reset instructions when the user exists" do
      expect do
        post "/auth/password/forgot",
             params: { email: user.email }.to_json,
             headers: headers
      end.to change(ActionMailer::Base.deliveries, :count).by(1)

      expect(response).to have_http_status(:ok)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to include(user.email)
      expect(mail.body.encoded).to include(
        Rails.application.config.x.web_app_url
      )
    end

    it "still returns success for unknown email without sending mail" do
      expect do
        post "/auth/password/forgot",
             params: { email: "unknown@example.com" }.to_json,
             headers: headers
      end.not_to change(ActionMailer::Base.deliveries, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /auth/password/reset" do
    let!(:user) do
      User.create!(
        email: "reset@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )
    end

    it "resets the password with a valid token and invalidates it afterwards" do
      token = user.send_reset_password_instructions

      post "/auth/password/reset",
           params: { token: token, password: "Newpass01!" }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("success" => true)
      expect(user.reload.valid_password?("Newpass01!")).to be(true)

      post "/auth/password/reset",
           params: { token: token, password: "Another01!" }.to_json,
           headers: headers

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("invalid_or_expired_token")
    end

    it "rejects an invalid token" do
      post "/auth/password/reset",
           params: { token: "invalid", password: "Another01!" }.to_json,
           headers: headers

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("invalid_or_expired_token")
    end

    it "returns validation errors when password is too weak" do
      token = user.send_reset_password_instructions

      post "/auth/password/reset",
           params: { token: token, password: "short" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["errors"]).to be_an(Array)
      expect(body["errors"].first["field"]).to eq("password")
    end
  end
end
