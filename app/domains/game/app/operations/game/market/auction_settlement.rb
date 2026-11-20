module Game
  module Market
    module AuctionSettlement
      include MoveHoldings

      private

      def settle_sale(listing:, winner_id:, held:, final_price:, now:)
        card = listing.card_season_id
        holdings = lock_sale_holdings(listing.seller_id, winner_id, card)
        give_sold_copy(listing.seller_id, holdings, card, released: { card => 1 }, now:)
        receive_bought_copy(winner_id, holdings, card, now:)
        listing.update!(status: "sold", sold_at: now, final_price:)
        Bid.close_out(listing_id: listing.id, winner_id:)
        listing.update!(average_after_sale: refresh_edition_price(card, now))
        sale_entries(buyer_id: winner_id, seller_id: listing.seller_id, price: final_price, held:, reference: { listing_id: listing.id },
          settings_id: listing.settings_id, commission_settings: Settings.find(listing.settings_id))
      end

      def give_sold_copy(seller_id, holdings, card, released:, now:)
        move(seller_id, holdings.fetch(seller_id), given: { card => 1 }, gained: {}, released:, now:)
        ShowcaseEntry.remove_unheld(seller_id, [ card ])
      end

      def receive_bought_copy(buyer_id, holdings, card, now:)
        season = Catalog::PublishedSeason.call
        step ReceiveSeasonAllocation.new.call(player: Accounts::Player.find(buyer_id), season:)
        move(buyer_id, holdings.fetch(buyer_id), given: {}, gained: { card => 1 }, released: {}, now:)
        reached = season ? SetTier.record(player_id: buyer_id, card_season_ids: [ card ], season_id: season.id, reached_by: "trade", pack_id: nil, now:) : {}
        step publish_tiers(buyer_id, reached)
      end

      # `adding`: the price of a sale not saved yet, the newest of its window.
      def refresh_edition_price(card_season_id, now, adding: nil)
        row = EditionPrice.lock_row(card_season_id)
        settings = CurrentSettings.call
        prices = EditionPrice.sales_in_window(card_season_id, settings:, now:)
        prices = [ adding, *prices ].first(settings.average_sale_count) if adding
        average = EditionPrice.average_of(prices)
        row.update!(average:, sales_used: prices.size, refreshed_at: now)
        average
      end

      def sold_event(listing:, winner_id:, final_price:, surplus:)
        AuctionSold.new(data: { listing_id: listing.id, seller_id: listing.seller_id, winner_id:, card_season_id: listing.card_season_id, final_price:, surplus: })
      end

      def publish_to_seller(listing, event) = publish(event, stream_name: stream_name(listing.seller_id))

      def lock_sale_holdings(seller_id, winner_id, card)
        [ seller_id, winner_id ].sort.to_h { |player_id| [ player_id, TradeLocks.holdings(player_id, [ card ]) ] }
      end

      # `reference`: the listing or the order the sale settles; purchase and sale at `settings_id`, the commission at `commission_settings`.
      def sale_entries(buyer_id:, seller_id:, price:, held:, reference:, settings_id:, commission_settings:)
        entry = ->(player_id, kind, available, committed = 0, version = settings_id) do
          Ledger::Entry.new(player_id:, kind:, available_delta: available, committed_delta: committed, settings_id: version, **reference)
        end
        commission = AuctionMath.commission(price, commission_settings.commission_basis_points)
        surplus = held - price
        [ entry.(buyer_id, :purchase, 0, -price), entry.(buyer_id, :release, surplus, -surplus),
          entry.(seller_id, :sale, price), entry.(seller_id, :commission, -commission, 0, commission_settings.id) ]
          .reject { it.available_delta.zero? && it.committed_delta.zero? }
      end
    end
  end
end
