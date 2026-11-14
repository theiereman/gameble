module Market
  # The desk heading every market tab: the market's pulse and the player's purse.
  module DeskLoading
    extend ActiveSupport::Concern

    private
      def load_desk
        @pulse = Game::Market::MarketPulse.call(locale: I18n.locale)
        @desk = Game::Market::PlayerDesk.call(current_player) if current_player
      end
  end
end
