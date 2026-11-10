module Market
  class ListingsController < ApplicationController
    include PublicRead

    def show
      authorize %i[market listing], :show?
      @listing = Game::Market::ListingByToken.call(params[:token], locale: I18n.locale) || raise(ActiveRecord::RecordNotFound)
      @history = Game::Market::BidHistory.call(token: @listing.token, viewer: current_player)
      @sheet = Game::Market::BidSheet.call(token: @listing.token, player: current_player)
      @focus = "field" if @sheet && params[:focus] == "maximum"
      @outcome = Game::Market::ListingOutcome.call(token: @listing.token, viewer: current_player, locale: I18n.locale)
    end
  end
end
