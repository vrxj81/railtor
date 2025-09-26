require "jwt"
require "securerandom"

class JwtTokenService
  TokenExpiredError = Class.new(StandardError)
  TokenDecodeError = Class.new(StandardError)

  class << self
    def issue_access_token(user, jti: SecureRandom.uuid, issued_at: Time.current)
      expires_at = issued_at + access_token_ttl
      build_token(user:, jti:, issued_at:, expires_at:, type: "access")
    end

    def issue_refresh_token(user, jti: SecureRandom.uuid, issued_at: Time.current)
      expires_at = issued_at + refresh_token_ttl
      build_token(user:, jti:, issued_at:, expires_at:, type: "refresh")
    end

    def decode!(token)
      payload, = JWT.decode(token, secret, true, { algorithm: "HS256" })
      payload.with_indifferent_access
    rescue JWT::ExpiredSignature => e
      raise TokenExpiredError, e.message
    rescue JWT::DecodeError => e
      raise TokenDecodeError, e.message
    end

    def access_token_expires_in
      access_token_ttl
    end

    def refresh_token_expires_in
      refresh_token_ttl
    end

    private

    def build_token(user:, jti:, issued_at:, expires_at:, type: "access")
      payload = {
        sub: user.id,
        role: user.role,
        iat: issued_at.to_i,
        exp: expires_at.to_i,
        jti: jti
      }
      payload[:typ] = type

      JWT.encode(payload, secret, "HS256")
    end

    def secret
      Rails
        .application
        .credentials
        .dig(:devise, :jwt_secret_key) || ENV["DEVISE_JWT_SECRET_KEY"] || Rails.application.secret_key_base
    end

    def access_token_ttl
      5.minutes
    end

    def refresh_token_ttl
      14.days
    end
  end
end
