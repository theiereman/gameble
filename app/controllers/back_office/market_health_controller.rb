module BackOffice
  class MarketHealthController < BaseController
    def show
      authorize [ :back_office, :market_health ], :show?
      settings = Game::Market::CurrentSettings.call
      @series = Game::Market::EconomySeries.call(settings:)
      @alerts = Game::Market::EconomyAlerts.call(@series, settings).index_by(&:indicator)
      @can_prepare = policy([ :back_office, :market_setting ]).create?
      @oldest_due_seconds = Game::Market::OldestDueListing.call
      @oldest_due_order_seconds = Game::Market::OldestDueOrder.call
      @income_rarity = Catalog::Rarity::TIERS.values.find { it.to_s == params[:rarity] } || :epic
    end
  end
end
