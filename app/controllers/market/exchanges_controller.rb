module Market
  class ExchangesController < ApplicationController
    include PublicRead

    def show
      authorize %i[market exchange], :show?
      raise ActiveRecord::RecordNotFound unless current_player&.staff?

      @reactor = Game::Market::EconomySeries.reactor
    end
  end
end
