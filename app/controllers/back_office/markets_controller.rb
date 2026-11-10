module BackOffice
  class MarketsController < BaseController
    def show
      authorize [ :back_office, :market ], :show?
      @state = Game::Market::MarketState.call
      @opening = Opening.new
    end

    Opening = Data.define(:terms_confirmed, :odds_confirmed, :message_fr, :message_en, :refusal) do
      def initialize(terms_confirmed: false, odds_confirmed: false, message_fr: nil, message_en: nil, refusal: nil) = super
    end
  end
end
