require "rails_helper"

RSpec.describe "Auth API", type: :request do
  let(:password) { "Supersafe01!" }
  let(:headers) { { "CONTENT_TYPE" => "application/json" } }

  describe "POST /auth/sign_up" do
    it "creates a new user and returns basic profile" do
      payload = { email: "new_user@example.com", password: password }

      post "/auth/sign_up", params: payload.to_json, headers: headers

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      expect(body).to include("id", "email", "role")
      expect(body["email"]).to eq("new_user@example.com")
      expect(body["role"]).to eq("customer")
      expect(User.find_by(email: "new_user@example.com")).to be_present
    end

    it "fails when email has already been taken" do
      User.create!(
        email: "duplicate@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )

      payload = { email: "duplicate@example.com", password: password }

      post "/auth/sign_up", params: payload.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["errors"]).to be_an(Array)
    end
  end

  describe "POST /auth/sign_in" do
    let!(:user) do
      User.create!(
        email: "login@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )
    end

    it "returns access and refresh tokens" do
      payload = { email: user.email, password: password }

      post "/auth/sign_in", params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["accessToken"]).to be_a(String)
      expect(body["refreshToken"]).to be_a(String)
      expect(body["user"]).to include(
        "id" => user.id,
        "email" => user.email,
        "role" => "customer"
      )
      expect(user.refresh_tokens.active.count).to eq(1)
    end

    it "increments failed attempts and returns invalid credentials" do
      payload = { email: user.email, password: "WrongPassword01!" }

      post "/auth/sign_in", params: payload.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("invalid_credentials")
      expect(user.reload.failed_attempts).to eq(1)
    end

    it "locks the account after five failures" do
      payload = { email: user.email, password: "WrongPassword01!" }

      5.times do
        post "/auth/sign_in", params: payload.to_json, headers: headers
      end

      expect(response).to have_http_status(:locked)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("account_locked")
      expect(user.reload.access_locked?).to be(true)
    end

    it "automatically unlocks after fifteen minutes" do
      5.times do
        post "/auth/sign_in",
             params: { email: user.email, password: "WrongPassword01!" }.to_json,
             headers: headers
      end

      expect(response).to have_http_status(:locked)

      travel_to(Time.current + 16.minutes) do
        post "/auth/sign_in",
             params: { email: user.email, password: password }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end

      expect(user.reload.access_locked?).to be(false)
    end
  end

  describe "POST /auth/refresh" do
    let!(:user) do
      User.create!(
        email: "refresh@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )
    end

    it "rotates refresh token and invalidates the old one" do
      tokens = sign_in_as(user)

      post "/auth/refresh",
           params: { refreshToken: tokens[:refresh_token] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["refreshToken"]).to be_a(String)
      expect(body["refreshToken"]).not_to eq(tokens[:refresh_token])

      post "/auth/refresh",
           params: { refreshToken: tokens[:refresh_token] }.to_json,
           headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq(
        "invalid_refresh_token"
      )
    end
  end

  describe "rate limiting" do
    let!(:user) do
      User.create!(
        email: "ratelimit@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )
    end

    before do
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    end

    it "returns 429 after exceeding the request budget" do
      payload = { email: user.email, password: password }

      10.times do
        post "/auth/sign_in", params: payload.to_json, headers: headers
        expect(response).to have_http_status(:ok)
      end

      post "/auth/sign_in", params: payload.to_json, headers: headers

      expect(response).to have_http_status(:too_many_requests)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("rate_limited")
    end
  end

  describe "POST /auth/sign_out" do
    let!(:user) do
      User.create!(
        email: "logout@example.com",
        password: password,
        confirmed_at: Time.current,
        role: :customer
      )
    end

    it "revokes the refresh token" do
      tokens = sign_in_as(user)

      post "/auth/sign_out",
           params: { refreshToken: tokens[:refresh_token] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)

      post "/auth/refresh",
           params: { refreshToken: tokens[:refresh_token] }.to_json,
           headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  def sign_in_as(user)
    payload = { email: user.email, password: password }

    post "/auth/sign_in", params: payload.to_json, headers: headers
    body = JSON.parse(response.body)

    {
      access_token: body["accessToken"],
      refresh_token: body["refreshToken"]
    }
  end
end
