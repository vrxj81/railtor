class SettingsPolicy < ApplicationPolicy
  def show?
    admin?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
