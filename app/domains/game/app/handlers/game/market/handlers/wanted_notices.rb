module Game
  module Market
    module Handlers
      module WantedNotices
        def self.call(event)
          listing_ids = event.is_a?(WantedChoicesApplied) ? event.data[:listing_ids] : [ event.data[:listing_id] ]
          Listing.where(id: listing_ids).order(:id).each { notice(event, it) }
        end

        def self.notice(event, listing)
          converted = ConvertedOrders.rows(event.data).select { it[:listing_id] == listing.id }.map { it[:owner_id] }
          player_ids = WantingPlayers.call(listing.card_season_id, except: [ listing.seller_id, *converted ])
          below = orders_below(listing, player_ids)
          player_ids.each do |player_id|
            attributes = { player_id:, listing_id: listing.id, amount: listing.starting_price }
            if (order_id = below[player_id])
              Notice.record_for(event, **attributes, order_id:, kind: "listed_above_order", other_player_id: listing.seller_id)
            else
              Notice.record_for(event, **attributes, kind: "wanted")
            end
          end
        end

        def self.orders_below(listing, player_ids)
          card_id, rarity = Catalog::CardSeason.where(id: listing.card_season_id).pick(:card_id, :rarity)
          return {} if player_ids.empty? || rarity.nil?

          Order.open_at(Time.current).reaching(rarity).where(card_id:, player_id: player_ids)
            .where(game_market_orders: { price: ...listing.starting_price }).pluck(:player_id, :id).to_h
        end

        private_class_method :notice, :orders_below
      end
    end
  end
end
