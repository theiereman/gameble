module Game
  # An entry of the activity feed, named by its player. A pull or a first
  # discovery is one card of an opened pack, unique per pack and position,
  # written only by Game::Handlers::PackOpenedFeed in the opening's
  # transaction: `notable` pulls are Épique or better, a filler is the best
  # card of a pack that held none, kept so a quiet feed is never empty, and a
  # discovery is notable whatever its rarity. A repost is a card a player
  # shared, with no pack, written only by Game::Handlers::CardRepostedFeed.
  # Its `kind` is what the feed's type filters read; visibility is not
  # stored but asked when it is shown.
  class FeedEntry < ApplicationRecord
    self.table_name = "game_feed_entries"

    # The lowest tier of a notable pull (Catalog::Rarity::TIERS: Épique).
    NOTABLE_TIER = 4

    # The kinds of entry (the database checks the same list); only pulls and
    # discoveries carry a pack and a position.
    KINDS = %w[pull discovery trade repost].freeze

    scope :newest_first, -> { order(occurred_at: :desc, id: :desc) }

    # Puts in the feed the cards of `pack` this opening discovered first
    # (`discovered`, card-season ids: the first position of each, as a
    # `discovery`, whatever its rarity, story 6.7) and its other notable
    # cards (as pulls), or, when it holds neither, its best card as a filler
    # (the first drawn on a tie): one insert, a duplicate (an event handled
    # twice) is skipped and never fails.
    def self.record_pack(pack, rarities, now, discovered: [])
      cards = pack.card_season_ids.each_with_index.filter_map { |id, position| [ id, position, rarities[id] ] if rarities[id] }
      firsts = discovered.filter_map { |id| cards.find { |card_id, _, _| card_id == id }&.at(1) }
      chosen = cards.filter_map do |id, position, tier|
        if firsts.include?(position) then [ id, position, tier, "discovery" ]
        elsif tier >= NOTABLE_TIER then [ id, position, tier, "pull" ]
        end
      end
      notable = chosen.any?
      chosen = [ cards.max_by { |_, position, tier| [ tier, -position ] } ].compact.map { |card| [ *card, "pull" ] } unless notable
      return if chosen.empty?

      rows = chosen.map do |id, position, tier, kind|
        { kind:, player_id: pack.player_id, pack_id: pack.id, card_season_id: id, position:, rarity: tier,
          notable:, occurred_at: now, created_at: now, updated_at: now }
      end
      insert_all(rows, unique_by: %i[pack_id position], record_timestamps: false)
    end

    def self.record_repost(player_id:, card_season_id:, at:)
      rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity)
      create!(kind: "repost", player_id:, card_season_id:, rarity: Catalog::Rarity::TIERS.key(rarity.to_sym),
        notable: true, occurred_at: at)
    end
  end
end
