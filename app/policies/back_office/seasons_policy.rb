module BackOffice
  class SeasonsPolicy < ApplicationPolicy
    def index? = administrator?
    def show? = administrator?
    def publish? = administrator?
  end
end
