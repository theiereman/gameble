module Game
  module Market
    module Handlers
      module RemovalNotices
        def self.call(event)
          data = event.data
          at = event.metadata[:timestamp] || Time.current
          case event
          when LeadVoided then Notice.record(player_id: data[:seller_id], listing_id: data[:listing_id], kind: "lead_voided", at:)
          end
        end
      end
    end
  end
end
