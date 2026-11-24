module Game
  module Market
    module Handlers
      module OutcomeNotices
        def self.call(event)
          case event
          when AuctionSold then sold(event, event.data)
          when AuctionUnsold then unsold(event, event.data)
          end
        end

        def self.sold(event, data)
          listing_id, seller_id, winner_id, price = data.values_at(:listing_id, :seller_id, :winner_id, :final_price)
          Notice.record_for(event, player_id: winner_id, listing_id:, kind: "won", amount: price)
          Notice.record_for(event, player_id: seller_id, listing_id:, kind: "sold", amount: received(listing_id, seller_id)) if seller_id
        end

        def self.unsold(event, data)
          Notice.record_for(event, player_id: data[:seller_id], listing_id: data[:listing_id], kind: "unsold") if data[:seller_id]
        end

        def self.received(listing_id, seller_id)
          LedgerEntry.where(listing_id:, player_id: seller_id, kind: %w[sale commission]).sum(:available_delta)
        end

        private_class_method :sold, :unsold, :received
      end
    end
  end
end
