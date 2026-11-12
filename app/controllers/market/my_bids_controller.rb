module Market
  class MyBidsController < ApplicationController
    def show
      authorize %i[market my_bid], :show?
      @groups = Game::Market::BidderListings.call(player: current_player, locale: I18n.locale)
      @suspended = Game::Market::MarketState.call.suspended?
      @ending_soon = Game::Market::MarketPulse.call(locale: I18n.locale, limit: 0).ending_soon if @groups.in_progress.empty? && @groups.recent.empty?
    end
  end
end
