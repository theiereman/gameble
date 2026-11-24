module Game
  module Market
    class ListCard < Operation
      include ListingOpening

      def call(player:, card_season_id:, starting_price:, duration_hours:, settings_token:)
        player = step require_player(player)
        starting_price = step amount(starting_price)

        transaction do
          step lock_bank(player)
          settings = step current_settings(settings_token)
          rarity = step rarity_of(card_season_id)
          holding = step free_copy(TradeLocks.holdings(player.id, [ card_season_id ])[card_season_id])
          step price_rule(settings, rarity, starting_price)
          step duration_rule(settings, duration_hours)
          step stamp_covered(settings, rarity, player)
          listing, stamp = open_listing(player, holding, settings, rarity, starting_price, duration_hours)
          Ledger.post(stamp)
          step publish(CardListed.with(listing_id: listing.id, seller_id: player.id, card_season_id:), stream_name: stream_name(player.id))
          listing
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def rarity_of(card_season_id)
        rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity)
        rarity ? Success(rarity.to_sym) : Failure(:no_rarity)
      end

      def free_copy(holding) = holding && holding.quantity > holding.reserved ? Success(holding) : Failure(:copy_not_free)

      def stamp_covered(settings, rarity, player)
        Balance.call(player).available >= settings.stamp(rarity) ? Success() : Failure(:stamp_not_covered)
      end
    end
  end
end
