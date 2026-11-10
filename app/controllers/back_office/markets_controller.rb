module BackOffice
  class MarketsController < BaseController
    include MarketPage

    def show
      authorize [ :back_office, :market ], :show?
      @settings_form = settings_form_for_page
      @state = Game::Market::MarketState.call
      @opening = Opening.new
    end

    Opening = Data.define(:terms_confirmed, :odds_confirmed, :message_fr, :message_en, :refusal) do
      def initialize(terms_confirmed: false, odds_confirmed: false, message_fr: nil, message_en: nil, refusal: nil) = super
    end
  end
end
