module BackOffice
  class MarketsController < BaseController
    include MarketPage

    def show
      authorize [ :back_office, :market ], :show?
      @settings_form = prepared_settings_form || settings_form_for_page
      @state = Game::Market::MarketState.call
      @opening = Opening.new
      @closing = Closing.new
    end

    Closing = Data.define(:message_fr, :message_en, :refusal) do
      def initialize(message_fr: nil, message_en: nil, refusal: nil) = super
    end

    Opening = Data.define(:terms_confirmed, :odds_confirmed, :message_fr, :message_en, :refusal) do
      def initialize(terms_confirmed: false, odds_confirmed: false, message_fr: nil, message_en: nil, refusal: nil) = super
    end

    private
      def prepared_settings_form
        settings = Game::Market::CurrentSettings.call
        return unless settings && params[:prepare].present? && policy([ :back_office, :market_setting ]).create?

        alert = Game::Market::EconomyAlerts.named(params[:prepare], Game::Market::EconomySeries.call(settings:), settings)
        MarketSettingsForm.from_settings(settings).prepare(alert.changes) if alert&.actionable?
      end
  end
end
