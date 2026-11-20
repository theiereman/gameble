module BackOffice
  class DuelsController < BaseController
    def show
      authorize [ :back_office, :duels ], :show?
      @versions = Game::DuelBalance.versions
      version = Integer(params[:version], exception: false)
      @version = @versions.include?(version) ? version : Game::DuelRules::VERSION
      @report = Game::DuelBalance.call(@version)
    end
  end
end
