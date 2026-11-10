module BackOffice
  class MarketOpeningsController < BaseController
    include MarketPage

    rate_limit to: 10, within: 1.minute, only: :create

    def create
      authorize [ :back_office, :market_opening ], :create?

      result = Game::Market::OpenMarket.new.call(player: current_player, terms_confirmed: params[:terms_confirmed] == "1",
        odds_confirmed: params[:odds_confirmed] == "1", message_fr: params[:message_fr], message_en: params[:message_en])
      if result.success?
        redirect_to back_office_market_path, notice: t(".opened"), status: :see_other
      else
        render_refused(result.failure)
      end
    end

    private
      def render_refused(code)
        @settings_form = settings_form_for_page
        @opening = MarketsController::Opening.new(terms_confirmed: params[:terms_confirmed] == "1", odds_confirmed: params[:odds_confirmed] == "1",
          message_fr: params[:message_fr], message_en: params[:message_en], refusal: Game::Market::OpenMarket.failure_message(code))
        render_market_page(status: :unprocessable_content)
      end
  end
end
