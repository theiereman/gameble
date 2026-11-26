module BackOffice
  class SupportersPolicy < ApplicationPolicy
    def create? = administrator?
    def destroy? = administrator?
  end
end
