module Game
  module Market
    module AuctionSettlement
      include MoveHoldings

      private

      def settle_sale(listing:, winner_id:, held:, final_price:, now:)
        season = Catalog::PublishedSeason.call
        card = listing.card_season_id
        holdings = lock_sale_holdings(listing.seller_id, winner_id, card)
        step ReceiveSeasonAllocation.new.call(player: Accounts::Player.find(winner_id), season:)
        move(listing.seller_id, holdings.fetch(listing.seller_id), given: { card => 1 }, gained: {}, released: { card => 1 }, now:)
        move(winner_id, holdings.fetch(winner_id), given: {}, gained: { card => 1 }, released: {}, now:)
        ShowcaseEntry.remove_unheld(listing.seller_id, [ card ])
        reached = season ? SetTier.record(player_id: winner_id, card_season_ids: [ card ], season_id: season.id, reached_by: "trade", pack_id: nil, now:) : {}
        step publish_tiers(winner_id, reached)
        listing.update!(status: "sold", sold_at: now, final_price:)
        Bid.close_out(listing_id: listing.id, winner_id:)
        refresh_edition_price(listing, now)
        sale_entries(listing, winner_id, held, final_price)
      end

      def refresh_edition_price(listing, now)
        row = EditionPrice.lock_row(listing.card_season_id)
        prices = EditionPrice.sales_in_window(listing.card_season_id, settings: CurrentSettings.call, now:)
        average = EditionPrice.average_of(prices)
        row.update!(average:, sales_used: prices.size, refreshed_at: now)
        listing.update!(average_after_sale: average)
      end

      def sold_event(listing:, winner_id:, final_price:, surplus:, outbid_player_id: nil, outbid_released: 0)
        AuctionSold.new(data: { listing_id: listing.id, seller_id: listing.seller_id, winner_id:, card_season_id: listing.card_season_id, final_price:,
          surplus:, outbid_player_id:, outbid_released: })
      end

      def publish_to_seller(listing, event) = publish(event, stream_name: stream_name(listing.seller_id))

      def lock_sale_holdings(seller_id, winner_id, card)
        [ seller_id, winner_id ].sort.to_h { |player_id| [ player_id, TradeLocks.holdings(player_id, [ card ]) ] }
      end

      def sale_entries(listing, winner_id, held, price)
        entry = ->(player_id, kind, available, committed = 0) do
          Ledger::Entry.new(player_id:, kind:, available_delta: available, committed_delta: committed, listing_id: listing.id, settings_id: listing.settings_id)
        end
        commission = AuctionMath.commission(price, Settings.find(listing.settings_id).commission_basis_points)
        surplus = held - price
        [ entry.(winner_id, :purchase, 0, -price), entry.(winner_id, :release, surplus, -surplus),
          entry.(listing.seller_id, :sale, price), entry.(listing.seller_id, :commission, -commission) ].reject { it.available_delta.zero? && it.committed_delta.zero? }
      end
    end
  end
end
