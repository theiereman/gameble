module Game
  module Market
    module Handlers
      module RemovalNotices
        def self.call(event)
          data = event.data
          at = event.metadata[:timestamp] || Time.current
          case event
          when ListingWithdrawn then withdrawn(data, at)
          when LeadVoided then Notice.record(player_id: data[:seller_id], listing_id: data[:listing_id], kind: "lead_voided", at:)
          end
        end

        def self.withdrawn(data, at)
          return unless data[:leader_id]

          Notice.record(player_id: data[:leader_id], listing_id: data[:listing_id], kind: "withdrawn", amount: data[:released], at:)
        end

        private_class_method :withdrawn
      end
    end
  end
end
