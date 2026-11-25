module Market
  # What heads every market tab: the market's pulse, the player's purse, how many of their copies other players want, and the Archives' shop.
  module DeskLoading
    extend ActiveSupport::Concern
    include GoalMarksLoading
    include Market::Storefront

    private
      def load_desk
        @pulse = Game::Market::MarketPulse.call(locale: I18n.locale)
        @desk = Game::Market::PlayerDesk.call(current_player) if current_player
        load_wanted_copies if current_player
        load_shop_panel
      end

      def load_wanted_copies
        @wanted_copies = Game::Market::WantedCopies.call(current_player)
      end

      def load_shop_panel
        @settings ||= Game::Market::CurrentSettings.call
        return unless @settings

        @buyable = buyable?(Game::Market::MarketState.call(@settings)) if @buyable.nil?
        @caps ||= Game::Market::ArchiveCaps.call(player: current_player, settings: @settings)
        @shop_count = Game::Market::ArchiveOffers.count(settings: @settings, locale: I18n.locale).cards
        @shop_offers = Game::Market::ArchiveOffers.featured(settings: @settings, wanted_card_ids:, locale: I18n.locale)
        @shop_marks = ListingMarks.for(current_player, @shop_offers, goal_marks, wanted_card_ids)
      end
  end
end
