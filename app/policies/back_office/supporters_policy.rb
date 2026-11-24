module BackOffice
  class SupportersPolicy < ApplicationPolicy
    def create? = administrator?
  end
end
