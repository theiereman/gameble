module Game
  module Handlers
    module PackOpenedFeed
      def self.call(event)
        pack = Pack.find(event.data.fetch(:pack_id))
        rarities = Catalog::CardSeasonTiers.call(pack.card_season_ids)
        discovered = FirstDiscovery.where(pack_id: pack.id).pluck(:card_season_id)
        FeedEntry.record_pack(pack, rarities, pack.opened_at || Time.current, discovered:)
      end
    end
  end
end
