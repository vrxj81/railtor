class AuditLogger
  class << self
  def log(event:, user: nil, ip: nil, metadata: {})
      payload = {
        type: "audit",
        event: event,
        user_id: user&.id,
        ip: ip,
        metadata: metadata.presence,
        timestamp: Time.current.utc.iso8601
      }.compact

      Rails.logger.info(payload.to_json)
    end
  end
end
