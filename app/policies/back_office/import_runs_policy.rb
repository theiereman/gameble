module BackOffice
  class ImportRunsPolicy < ApplicationPolicy
    def index? = administrator?
    def show? = administrator?
    def create? = administrator?
    def resume? = administrator?
    def rescore? = administrator?
    def abandon? = administrator?
    def promote? = administrator?
    def discard? = administrator?
  end
end
