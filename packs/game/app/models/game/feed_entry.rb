module Game
  # An entry of the activity feed (CAP-13, AD-10): one card of an opened
  # pack, named by the player who pulled it. `notable` entries are pulls of
  # Épique or better; a filler is the best card of a pack that held none,
  # kept so a quiet feed is never empty (R4). Unique per pack and position.
  # Written only by Game::Handlers::PackOpenedFeed, in the opening's
  # transaction; visibility is not stored but asked when it is shown (AD-13).
  class FeedEntry < ApplicationRecord
    self.table_name = "game_feed_entries"

    # The lowest tier of a notable pull (Catalog::Rarity::TIERS: Épique).
    NOTABLE_TIER = 4

    scope :newest_first, -> { order(occurred_at: :desc, id: :desc) }

    # Puts the notable cards of `pack` in the feed, or, when it holds none,
    # its best card as a filler (the first drawn on a tie): one insert, a
    # duplicate (an event handled twice) is skipped and never fails.
    def self.record_pack(pack, rarities, now)
      tiers = pack.card_season_ids.each_with_index.map { |id, position| [ id, position, rarities[id] ] }.select(&:last)
      notable = tiers.select { |_, _, tier| tier >= NOTABLE_TIER }
      chosen = notable.presence || [ tiers.max_by { |_, position, tier| [ tier, -position ] } ].compact
      return if chosen.empty?

      rows = chosen.map do |id, position, tier|
        { player_id: pack.player_id, pack_id: pack.id, card_season_id: id, position:, rarity: tier,
          notable: notable.any?, occurred_at: now, created_at: now, updated_at: now }
      end
      insert_all(rows, unique_by: %i[pack_id position], record_timestamps: false)
    end
  end
end
