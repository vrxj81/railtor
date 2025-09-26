class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  ROLES = { admin: 0, editor: 1, service: 2, customer: 3 }.freeze

  devise :database_authenticatable,
         :recoverable,
         :confirmable,
         :lockable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: self

  enum :role, ROLES

  before_validation :normalize_email
  after_initialize :set_default_role, if: :new_record?

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, presence: true, inclusion: { in: roles.keys }

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def set_default_role
    self.role ||= :customer
  end
end
