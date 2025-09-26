return unless defined?(Rack::Attack)

store = Rails.cache
store = ActiveSupport::Cache::MemoryStore.new if store.is_a?(ActiveSupport::Cache::NullStore)
Rack::Attack.cache.store = store

Rack::Attack.throttle("auth-endpoints/ip", limit: 10, period: 1.minute) do |req|
  next unless req.path.start_with?("/auth/")
  next unless req.post?

  req.ip
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"] || {}
  retry_after = match_data[:period]

  body = {
    error: {
      code: "rate_limited",
      message: "Too many requests. Try again later."
    }
  }.to_json

  headers = {
    "Content-Type" => "application/json",
    "Cache-Control" => "no-store"
  }
  headers["Retry-After"] = retry_after.to_s if retry_after

  [429, headers, [body]]
end
