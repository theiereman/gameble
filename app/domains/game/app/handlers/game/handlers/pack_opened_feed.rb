module Game
  module Handlers
    # Chooses what an opening puts in the activity feed (CAP-13, AD-10,
    # AD-13: the choice lives in this one handler): the cards it discovered
    # first in their season (Game::FirstDiscovery, recorded by the opening
    # before its event, story 6.7), the pulls of Épique or better, or, for a
    # pack with neither, its best card as a filler. It runs in the opening's
    # transaction, writes only new feed rows in one insert that skips a
    # duplicate, and publishes nothing. Three reads and one insert, so the
    # opening stays inside its budget.
    module PackOpenedFeed
      def self.call(event)
        pack = Pack.find(event.data.fetch(:pack_id))
        ids = pack.card_season_ids.uniq
        rarities = Catalog::CardSeason.where(id: ids).where.not(rarity: nil).pluck(:id, :rarity)
          .to_h { |id, name| [ id, Catalog::Rarity::TIERS.key(name.to_sym) ] }
        discovered = FirstDiscovery.where(pack_id: pack.id).pluck(:card_season_id)
        FeedEntry.record_pack(pack, rarities, pack.opened_at || Time.current, discovered:)
      end
    end
  end
end
