module BackOffice
  class MarketSignalsController < BaseController
    def show
      authorize [ :back_office, :market_signals ], :show?
      @rows = Game::Market::AltSignalRows.call
      @refreshed_at = Game::Market::AltSignalRows.refreshed_at
    end
  end
end
