require "rails_helper"

RSpec.describe "db:seed" do
  let(:admin_password) { "AdminPassword01!" }
  let(:editor_password) { "EditorPassword01!" }
  let(:service_password) { "ServicePassword01!" }

  def with_seed_env
    overrides = {
      "ADMIN_EMAIL" => "admin.seed@example.com",
      "EDITOR_EMAIL" => "editor.seed@example.com",
      "SERVICE_EMAIL" => "service.seed@example.com",
      "ADMIN_PASSWORD" => admin_password,
      "EDITOR_PASSWORD" => editor_password,
      "SERVICE_PASSWORD" => service_password
    }

    previous_values = {}
    overrides.each do |key, value|
      previous_values[key] = ENV.key?(key) ? ENV[key] : :__unset__
      ENV[key] = value
    end

    yield
  ensure
    previous_values.each do |key, previous|
      if previous == :__unset__
        ENV.delete(key)
      else
        ENV[key] = previous
      end
    end
  end

  def run_seed
    load Rails.root.join("db/seeds.rb")
  end

  def fetch_user(email, password)
    user = User.find_by(email: email)
    expect(user).to be_present
    expect(user.valid_password?(password)).to be(true)
    user
  end

  before do
    User.delete_all
    allow($stdout).to receive(:puts)
  end

  it "creates admin, editor, and service accounts" do
    with_seed_env do
      run_seed

      admin = fetch_user("admin.seed@example.com", admin_password)
      editor = fetch_user("editor.seed@example.com", editor_password)
      service = fetch_user("service.seed@example.com", service_password)

      expect(admin.role).to eq("admin")
      expect(editor.role).to eq("editor")
      expect(service.role).to eq("service")
      expect(User.count).to eq(3)
    end
  end

  it "is idempotent when re-run" do
    with_seed_env do
      2.times { run_seed }

      expect(User.count).to eq(3)
      expect(User.pluck(:email)).to contain_exactly(
        "admin.seed@example.com",
        "editor.seed@example.com",
        "service.seed@example.com"
      )
    end
  end
end
