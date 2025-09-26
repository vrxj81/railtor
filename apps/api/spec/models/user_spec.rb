require 'rails_helper'

RSpec.describe User, type: :model do
  let(:password) { 'Supersafe01!' }

  describe 'validations' do
    it 'downcases email before validation' do
      user = described_class.new(email: 'Test@Example.COM', password:, role: :customer)

      expect { user.valid? }.to change(user, :email).to('test@example.com')
    end

    it 'enforces unique email case-insensitively' do
      described_class.create!(email: 'user@example.com', password:, role: :customer)

      duplicate = described_class.new(email: 'USER@example.com', password:, role: :customer)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include('has already been taken')
    end

    it 'validates presence of role' do
      user = described_class.new(email: 'role@example.com', password:)
      user.role = nil

      expect(user).not_to be_valid
      expect(user.errors[:role]).to include("can't be blank")
    end
  end

  describe 'roles enum' do
    it 'exposes the expected role values' do
      expect(described_class.roles).to eq(
        'admin' => 0,
        'editor' => 1,
        'service' => 2,
        'customer' => 3
      )
    end

    it 'defaults to customer' do
      user = described_class.new(email: 'default@example.com', password:)

      expect(user.role).to eq('customer')
    end

    it 'raises when assigning an undefined role' do
      expect do
        described_class.new(email: 'foo@example.com', password:, role: :invalid)
      end.to raise_error(ArgumentError)
    end
  end
end
