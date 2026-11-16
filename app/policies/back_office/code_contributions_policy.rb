module BackOffice
  class CodeContributionsPolicy < ApplicationPolicy
    def create? = administrator?
  end
end
