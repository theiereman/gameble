module Game
  module Market
    module Handlers
      module OrderNotices
        LISTING_ENDS = [ AuctionSold, AuctionUnsold, ListingWithdrawn, ListingCancelled ].freeze
        EVENTS = [ *LISTING_ENDS, OrderServed, OrderExpired, OrderCancelled, OrderWithdrawn, WantedChoicesApplied ].freeze

        def self.call(event)
          data = event.data
          case event
          when *LISTING_ENDS then Notice.listed_above_order.where(listing_id: data[:listing_id]).delete_all
          when OrderServed then served(event, data)
          when WantedChoicesApplied then data[:sales].each { served(event, it) }
          when OrderExpired then expired(event, data)
          else ended(data[:player_id], data[:order_id])
          end
        end

        def self.served(event, sale)
          ended(sale[:buyer_id], sale[:order_id])
          Notice.record_for(event, player_id: sale[:buyer_id], order_id: sale[:order_id], kind: "order_served", amount: sale[:price])
        end

        def self.expired(event, data)
          ended(data[:player_id], data[:order_id])
          Notice.record_for(event, player_id: data[:player_id], order_id: data[:order_id], kind: "order_expired", amount: data[:amount])
        end

        def self.ended(player_id, order_id) = Notice.listed_above_order.where(player_id:, order_id:).delete_all

        private_class_method :served, :expired, :ended
      end
    end
  end
end
