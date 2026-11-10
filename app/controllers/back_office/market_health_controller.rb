module BackOffice
  class MarketHealthController < BaseController
    def show
      authorize [ :back_office, :market_health ], :show?
      @series = Game::Market::EconomySeries.call
      @oldest_due_seconds = Game::Market::OldestDueListing.call
    end
  end
end
