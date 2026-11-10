module Market
  class ListingsController < ApplicationController
    include PublicRead

    def show
      authorize %i[market listing], :show?
      @listing = Game::Market::ListingByToken.call(params[:token], locale: I18n.locale) || raise(ActiveRecord::RecordNotFound)
    end
  end
end
