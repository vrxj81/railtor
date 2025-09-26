class ApplicationPolicy
  class NotAuthenticatedError < StandardError; end

  attr_reader :user, :record

  def initialize(user, record)
    raise NotAuthenticatedError, "You need to sign in before continuing." unless user

    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def admin?
    user.admin?
  end

  def editor?
    user.editor?
  end

  def service?
    user.service?
  end

  def customer?
    user.customer?
  end

  def allow_roles?(*roles)
    roles.any? { |role| user.public_send("#{role}?") }
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      raise NotAuthenticatedError, "You need to sign in before continuing." unless user

      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end
