module Market
  class BuyersController < ApplicationController
    include Market::DeskLoading

    def show
      authorize %i[market buyer], :show?
      @suspended = Game::Market::MarketState.call.suspended?
      load_desk
      @wanted_cards = Catalog::CardViews.call(@wanted_copies.map(&:card_season_id), locale: I18n.locale)
    end
  end
end
