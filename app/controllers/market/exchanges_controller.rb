module Market
  class ExchangesController < ApplicationController
    include PublicRead

    def show
      authorize %i[market exchange], :show?
      @charts = Game::Market::ChartPublications.for(current_player)
      raise ActiveRecord::RecordNotFound unless Game::Market::MarketState.call.first_opened? && @charts.exchange?

      @reactor = Game::Market::EconomySeries.reactor if @charts.staff_only?(:reactor)
      @snapshot_dated = ChartVersions::SnapshotDated.current
    end
  end
end
