module BackOffice
  class JobsPolicy < ApplicationPolicy
    def show? = administrator?
  end
end
