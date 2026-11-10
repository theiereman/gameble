module Game
  module Market
    module Handlers
      module OutbidNotices
        def self.call(event)
          data = event.data
          outbid_player_id = data[:outbid_player_id]
          return unless outbid_player_id

          Notice.record(player_id: outbid_player_id, listing_id: data[:listing_id], kind: "outbid", other_player_id: other_player_id(event),
            amount: data[:outbid_released], at: event.metadata[:timestamp] || Time.current)
        end

        def self.other_player_id(event)
          event.is_a?(BidPlaced) ? event.data[:bidder_id] : event.data[:winner_id]
        end
        private_class_method :other_player_id
      end
    end
  end
end
