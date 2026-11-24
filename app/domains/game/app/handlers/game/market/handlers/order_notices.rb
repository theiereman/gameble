module Game
  module Market
    module Handlers
      module OrderNotices
        LISTING_ENDS = [ AuctionSold, AuctionUnsold, ListingWithdrawn, ListingCancelled ].freeze
        EVENTS = [ *LISTING_ENDS, CardListed, OrderServed, OrderExpired, OrderCancelled, OrderWithdrawn, WantedChoicesApplied ].freeze

        def self.call(event)
          data = event.data
          case event
          when *LISTING_ENDS then listing_ended(data[:listing_id])
          when CardListed then converted_rows(data).each { converted(event, it) }
          when OrderServed then served(event, data)
          when WantedChoicesApplied
            data[:sales].each { served(event, it) }
            converted_rows(data).each { converted(event, it) }
          when OrderExpired then expired(event, data)
          else ended(data[:player_id], data[:order_id])
          end
        end

        def self.converted_rows(data) = data.fetch(:converted, []).sort_by { [ it[:owner_id], it[:order_id] ] }

        def self.listing_ended(listing_id)
          Notice.listed_above_order.where(listing_id:).includes(:order).each do |notice|
            above = listing_above(notice.order, except: listing_id)
            notices = Notice.where(id: notice.id)
            above ? notices.update_all(listing_id: above.id, other_player_id: above.seller_id, amount: above.starting_price) : notices.delete_all
          end
        end

        def self.listing_above(order, except:)
          editions = Catalog::CardSeason.where(card_id: order.card_id, rarity: OrderRarities.call(order.id).fetch(order.id)).select(:id)
          Listing.open_now.where(card_season_id: editions).where.not(id: except).where.not(seller_id: order.player_id)
            .where("starting_price > ?", order.price).order(id: :desc).first
        end

        def self.served(event, sale)
          ended(sale[:buyer_id], sale[:order_id])
          Notice.record_for(event, player_id: sale[:buyer_id], order_id: sale[:order_id], kind: "order_served", amount: sale[:price])
        end

        def self.converted(event, row)
          ended(row[:owner_id], row[:order_id])
          Notice.record_for(event, player_id: row[:owner_id], order_id: row[:order_id], listing_id: row[:listing_id], amount: row[:price],
            kind: row[:status] == "bid" ? "order_leads" : "order_beaten")
        end

        def self.expired(event, data)
          ended(data[:player_id], data[:order_id])
          Notice.record_for(event, player_id: data[:player_id], order_id: data[:order_id], kind: "order_expired", amount: data[:amount])
        end

        def self.ended(player_id, order_id) = Notice.listed_above_order.where(player_id:, order_id:).delete_all

        private_class_method :converted_rows, :listing_ended, :listing_above, :served, :converted, :expired, :ended
      end
    end
  end
end
