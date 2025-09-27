require "securerandom"

def fetch_env!(key)
  ENV.fetch(key) do
    raise <<~MSG
			Missing required environment variable #{key.inspect}.
			Set it before running `rails db:seed`.
    MSG
  end
end

seed_users = [
  {
    role: :admin,
    email: ENV.fetch("ADMIN_EMAIL", "admin@railtor.local"),
    password: fetch_env!("ADMIN_PASSWORD")
  },
  {
    role: :editor,
    email: ENV.fetch("EDITOR_EMAIL", "editor@railtor.local"),
    password: fetch_env!("EDITOR_PASSWORD")
  },
  {
    role: :service,
    email: ENV.fetch("SERVICE_EMAIL", "service@railtor.local"),
    password: fetch_env!("SERVICE_PASSWORD")
  }
]

seed_users.each do |attributes|
  email = attributes[:email].strip.downcase
  user = User.find_or_initialize_by(email: email)

  user.role = attributes[:role]
  user.password = attributes[:password]
  user.password_confirmation = attributes[:password]
  user.confirmed_at ||= Time.current
  user.failed_attempts = 0 if user.respond_to?(:failed_attempts=)
  user.locked_at = nil if user.respond_to?(:locked_at=)

  user.skip_confirmation! if user.new_record? && user.respond_to?(:skip_confirmation!)

  if user.changed?
    user.save!
    puts "Seeded #{attributes[:role]} user (#{email})."
  else
    puts "No changes for #{attributes[:role]} user (#{email})."
  end
end
