module BackOffice
  class ReleaseNotesPolicy < ApplicationPolicy
    def index? = administrator?
    def create? = administrator?
    def edit? = administrator?
    def save? = administrator?
    def preview? = administrator?
    def state? = administrator?
    def translate? = administrator?
    def condense? = administrator?
  end
end
