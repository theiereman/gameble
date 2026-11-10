module Game
  module Market
    module Handlers
      module OutbidNotices
        def self.call(event)
          data = event.data
          return unless data[:outbid_player_id]

          Notice.record(player_id: data[:outbid_player_id], listing_id: data[:listing_id], kind: "outbid", other_player_id: data[:bidder_id],
            amount: data[:outbid_released], at: event.metadata[:timestamp] || Time.current)
        end
      end
    end
  end
end
