module BackOffice
  # What the Marché page draws, shared by the controllers that re-render it after a refused save.
  module MarketPage
    private
      # The settings form for a version, or nil while the market was never opened and no version exists.
      def settings_form_for_page(settings = Game::Market::CurrentSettings.call)
        MarketSettingsForm.from_settings(settings) if settings
      end

      def render_market_page(status: :ok)
        @state = Game::Market::MarketState.call
        @opening ||= MarketsController::Opening.new
        render "back_office/markets/show", status:
      end
  end
end
