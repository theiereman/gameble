module BackOffice
  class AnnouncementsPolicy < ApplicationPolicy
    def index? = administrator?
    def create? = administrator?
    def update? = administrator?
    def publish? = administrator?
    def withdraw? = administrator?
  end
end
