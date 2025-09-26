require "uri"

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

if Rails.env.development?
  angular_origin =
    begin
      uri = URI.parse(Rails.configuration.x.web_app_url)
      port = uri.port && ![80, 443].include?(uri.port) ? ":#{uri.port}" : ""

      "#{uri.scheme}://#{uri.host}#{port}"
    rescue URI::InvalidURIError
      Rails.configuration.x.web_app_url
    end

  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins angular_origin

      resource "*",
               headers: ["Authorization", "Content-Type", "Accept"],
               expose: ["Authorization"],
               methods: %i[get post put patch delete options head],
               max_age: 600
    end
  end
end
