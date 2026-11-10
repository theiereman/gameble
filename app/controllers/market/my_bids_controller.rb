module Market
  class MyBidsController < ApplicationController
    def show
      authorize %i[market my_bid], :show?
      @groups = Game::Market::BidderListings.call(player: current_player, locale: I18n.locale)
    end
  end
end
