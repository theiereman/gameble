module BackOffice
  class CreditDonorsPolicy < ApplicationPolicy
    def index? = administrator?
    def create? = administrator?
    def destroy? = administrator?
  end
end
