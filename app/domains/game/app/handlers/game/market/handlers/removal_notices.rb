module Game
  module Market
    module Handlers
      module RemovalNotices
        def self.call(event)
          data = event.data
          case event
          when ListingWithdrawn then withdrawn(event, data)
          when LeadVoided then Notice.record_for(event, player_id: data[:seller_id], listing_id: data[:listing_id], kind: "lead_voided")
          end
        end

        def self.withdrawn(event, data)
          return unless data[:leader_id]

          Notice.record_for(event, player_id: data[:leader_id], listing_id: data[:listing_id], kind: "withdrawn", amount: data[:released])
        end

        private_class_method :withdrawn
      end
    end
  end
end
