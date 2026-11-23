module Game
  module Market
    # A player buys one copy of an edition from the Archives at the Archive price of the version in force; the PiCoins are destroyed.
    # A purchase token already used by this player answers the purchase it made, moving nothing, and refuses another edition.
    class BuyFromArchives < Operation
      include AuctionSettlement

      def call(player:, card_season_id:, purchase_token:, settings_token:)
        player = step require_player(player)
        purchase_token = step readable_token(purchase_token.to_s)

        transaction do
          step lock_bank(player)
          made = ArchiveWithdrawal.find_by(player_id: player.id, purchase_token:)
          next step(replayed(made, card_season_id)) if made

          settings = step current_settings(settings_token.to_s)
          price = step archive_price(settings, card_season_id)
          step covered(player, price)
          holdings = { player.id => TradeLocks.holdings(player.id, [ card_season_id ]) }
          stock = step locked_stock(card_season_id)
          now = Time.current
          withdrawal = ArchiveWithdrawal.create!(player_id: player.id, card_season_id:, purchase_token:, price:, settings_id: settings.id, created_at: now)
          take_copy(stock, now)
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

      def archive_price(settings, card_season_id)
        rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity)
        price = rarity && settings.archive_price(rarity)
        price ? Success(price) : Failure(:not_in_shop)
      end

      def covered(player, price) = Balance.call(player).available >= price ? Success() : Failure(:more_than_available)

      def locked_stock(card_season_id)
        stock = ArchiveStock.lock.find_by(card_season_id:)
        stock ? Success(stock) : Failure(:out_of_stock)
      end

      def take_copy(stock, now)
        if stock.quantity == 1
          stock.delete
        else
          ArchiveStock.where(id: stock.id).update_all([ "quantity = quantity - 1, updated_at = ?", now ])
        end
      end
    end
  end
end
