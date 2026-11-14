module Market
  class MySalesController < ApplicationController
    include Market::DeskLoading

    def show
      authorize %i[market my_sale], :show?
      @groups = Game::Market::SellerListings.call(player: current_player, locale: I18n.locale)
      @suspended = Game::Market::MarketState.call.suspended?
      load_desk
      @landing = params[:landing].to_s if params.key?(:landing)
    end
  end
end
