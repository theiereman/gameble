module BackOffice
  class CodeContributionsPolicy < ApplicationPolicy
    def create? = administrator?
    def destroy? = administrator?
  end
end
