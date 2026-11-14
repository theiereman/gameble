module Game
  module Market
    module Handlers
      module WantedNotices
        def self.call(event)
          data = event.data
          starting_price = Listing.where(id: data[:listing_id]).pick(:starting_price)
          WantingPlayers.call(data[:card_season_id], except: data[:seller_id]).each do |player_id|
            Notice.record_for(event, player_id:, listing_id: data[:listing_id], kind: "wanted", amount: starting_price)
          end
        end
      end
    end
  end
end
