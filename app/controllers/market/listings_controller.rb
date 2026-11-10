module Market
  class ListingsController < ApplicationController
    include PublicRead

    def show
      authorize %i[market listing], :show?
      @listing = Game::Market::ListingByToken.call(params[:token], locale: I18n.locale) || raise(ActiveRecord::RecordNotFound)
      @history = Game::Market::BidHistory.call(token: @listing.token, viewer: current_player)
      @outcome = Game::Market::ListingOutcome.call(token: @listing.token, viewer: current_player, locale: I18n.locale)
    end
  end
end
