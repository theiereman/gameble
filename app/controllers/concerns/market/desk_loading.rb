module Market
  # The desk heading every market tab: the market's pulse, the player's purse and their copies other players want.
  module DeskLoading
    extend ActiveSupport::Concern

    WANTED_TILES = 4

    private
      def load_desk
        @pulse = Game::Market::MarketPulse.call(locale: I18n.locale)
        @desk = Game::Market::PlayerDesk.call(current_player) if current_player
        load_wanted_copies if current_player
      end

      def load_wanted_copies
        @wanted_copies = Game::Market::WantedCopies.call(current_player)
        @wanted_tiles = @wanted_copies.first(WANTED_TILES)
        @wanted_cards = Catalog::CardViews.call(@wanted_tiles.map(&:card_season_id), locale: I18n.locale)
      end
  end
end
