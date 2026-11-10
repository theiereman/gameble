module Game
  module Market
    module Handlers
      module OutbidNotices
        def self.call(event)
          data = event.data
          return if data[:outbid_player_id].nil? || data[:outbid_player_id] == data[:bidder_id]

          Notice.record_for(event, player_id: data[:outbid_player_id], listing_id: data[:listing_id], kind: "outbid", other_player_id: data[:bidder_id],
            amount: data[:outbid_released])
        end
      end
    end
  end
end
