module Game
  module Market
    # Turns the eligible orders at or above an opened auction's starting price into its bids, under the seller's bank lock:
    # the best leads with its PiCoins moved to the listing, the others are beaten and refunded. Returns the event rows and the entries to post.
    module OrderConversion
      private

      def convert_orders(listing, settings, now)
        orders = lock_reaching_orders(listing, now)
        return [ [], [] ] if orders.empty?

        leader, *others = orders
        price = AuctionMath.displayed_price(highest: leader.price, second: others.first&.price, starting_price: listing.starting_price,
          basis_points: settings.increment_basis_points)
        listing.update!(leader_id: leader.player_id, leader_maximum: leader.price, current_price: price)
        orders.sort_by { [ it.created_at, it.id ] }.each { record_order_bid(listing, it, leader, price) }
        orders.each { it.update!(status: it.equal?(leader) ? "bid" : "beaten") }
        [ orders.map { converted_row(listing, it) }, order_entries(listing, orders, leader) ]
      end

      def lock_reaching_orders(listing, now)
        reaching = EligibleOrders.call(listing.card_season_id, except: listing.seller_id, now:).where(game_market_orders: { price: listing.starting_price.. })
        seen = reaching.pluck(:id, :player_id)
        TradeLocks.players(*seen.map(&:last))
        Order.where(id: seen.map(&:first)).order(:id).lock.pluck(:id)
        reaching.where(id: seen.map(&:first)).to_a
      end

      def record_order_bid(listing, order, leader, price)
        Bid.create!(listing:, player_id: order.player_id, maximum: order.price, price_after: price, outcome: order.equal?(leader) ? "leading" : "beaten")
      end

      def converted_row(listing, order)
        { order_id: order.id, owner_id: order.player_id, listing_id: listing.id, price: order.price, status: order.status }
      end

      def order_entries(listing, orders, leader)
        orders.flat_map do |order|
          release = Ledger::Entry.new(player_id: order.player_id, kind: :release, available_delta: order.price, committed_delta: -order.price,
            order_id: order.id, settings_id: order.settings_id)
          next [ release ] unless order.equal?(leader)

          [ release, Ledger::Entry.new(player_id: order.player_id, kind: :hold, available_delta: -order.price, committed_delta: order.price,
            listing_id: listing.id, settings_id: listing.settings_id) ]
        end
      end
    end
  end
end
