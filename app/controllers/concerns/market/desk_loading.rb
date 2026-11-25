module Market
  # The desk heading every market tab: the market's pulse, the player's purse and how many of their copies other players want.
  module DeskLoading
    extend ActiveSupport::Concern

    private
      def load_desk
        @pulse = Game::Market::MarketPulse.call(locale: I18n.locale)
        @desk = Game::Market::PlayerDesk.call(current_player) if current_player
        load_wanted_copies if current_player
      end

      def load_wanted_copies
        @wanted_copies = Game::Market::WantedCopies.call(current_player)
      end
  end
end
