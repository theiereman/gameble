module Market
  # The desk heading every market tab: the market's pulse, the player's purse and the commission.
  module DeskLoading
    extend ActiveSupport::Concern

    private
      def load_desk
        @pulse = Game::Market::MarketPulse.call(locale: I18n.locale)
        @desk = Game::Market::PlayerDesk.call(current_player) if current_player
        @commission_rate = Game::Market::CurrentSettings.call.commission_basis_points
      end
  end
end
