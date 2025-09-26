require "rails_helper"

RSpec.describe "Settings API", type: :request do
  describe "GET /settings" do
    it "returns 401 when unauthenticated" do
      get "/settings"

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("unauthenticated")
    end

    it "returns 403 when user is not an admin" do
      user = User.create!(
        email: "editor@example.com",
        password: "Password01!",
        confirmed_at: Time.current,
        role: :editor
      )
      token = JwtTokenService.issue_access_token(user)

      get "/settings", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("not_authorized")
    end

    it "allows admins to view settings" do
      user = User.create!(
        email: "admin@example.com",
        password: "Password01!",
        confirmed_at: Time.current,
        role: :admin
      )
      token = JwtTokenService.issue_access_token(user)

      get "/settings", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include("application", "features")
      expect(body.dig("application", "name")).to eq("Railtor")
    end
  end
end
