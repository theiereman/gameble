module Game
  module Market
    # A player buys one copy of an edition of the week's list at the week's price, once a week per edition and a few cards a week; the
    # PiCoins are destroyed. A price other than the one the player confirmed, as on Monday 00:00 UTC, is refused.
    # A purchase token already used by this player answers the purchase it made, moving nothing, and refuses another edition.
    class BuyFromArchives < Operation
      include AuctionSettlement

      def call(player:, card_season_id:, purchase_token:, settings_token:, price:)
        player = step require_player(player)
        purchase_token = step readable_token(purchase_token.to_s)

        transaction do
          step lock_bank(player)
          now = Time.current
          made = ArchiveWithdrawal.find_by(player_id: player.id, purchase_token:)
          next step(replayed(made, card_season_id)) if made

          settings = step current_settings(settings_token.to_s)
          rarity = step edition_rarity(card_season_id)
          step offered(settings, card_season_id)
          price = step archive_price(settings, rarity, price)
          step under_cap(player, now)
          step covered(player, price)
          holdings = { player.id => TradeLocks.holdings(player.id, [ card_season_id ]) }
          step not_bought_before(player, card_season_id)
          stock = step locked_stock(card_season_id)
          withdrawal = ArchiveWithdrawal.create!(player_id: player.id, card_season_id:, purchase_token:, price:, settings_id: settings.id, created_at: now)
          stock.take_one(now)
          receive_bought_copy(player.id, holdings, card_season_id, now:)
          Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :archive_purchase, available_delta: -price, settings_id: settings.id))
          step publish(ArchivePurchased.with(player_id: player.id, card_season_id:, price:), stream_name: stream_name(player.id))
          withdrawal
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def readable_token(token) = token.match?(ArchiveWithdrawal::PURCHASE_TOKEN_FORMAT) ? Success(token) : Failure(:invalid_purchase_token)

      def replayed(made, card_season_id) = made.card_season_id == card_season_id ? Success(made) : Failure(:invalid_purchase_token)

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def edition_rarity(card_season_id)
        rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity)
        rarity ? Success(rarity) : Failure(:not_in_shop)
      end

      def offered(settings, card_season_id)
        return Success() if ArchiveOffers.listed?(settings:, card_season_id:)

        Failure(ArchiveStock.exists?(card_season_id:) ? :not_in_shop : :out_of_stock)
      end

      def archive_price(settings, rarity, confirmed)
        price = ArchivePrices.call(settings).fetch(rarity.to_sym)
        return Failure(:amounts_changed) unless price == confirmed.to_i

        Success(price)
      end

      def under_cap(player, now)
        ArchiveCaps.call(player:, now:).values.first&.reached? ? Failure(:archive_cap_reached) : Success()
      end

      def covered(player, price) = Balance.call(player).available >= price ? Success() : Failure(:more_than_available)

      def locked_stock(card_season_id)
        stock = ArchiveStock.lock.find_by(card_season_id:)
        stock ? Success(stock) : Failure(:out_of_stock)
      end

      def not_bought_before(player, card_season_id)
        ArchiveOffers.bought_this_week?(player:, card_season_id:) ? Failure(:already_bought) : Success()
      end
    end
  end
end
