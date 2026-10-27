module BackOffice
  class ThemesPolicy < ApplicationPolicy
    def index? = administrator?
    def create? = administrator?
    def update? = administrator?
    def attach? = administrator?
    def dismiss? = administrator?
  end
end
