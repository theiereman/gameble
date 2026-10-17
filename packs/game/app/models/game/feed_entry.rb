module Game
  # An entry of the activity feed, named by its player. A pull or a first
  # discovery is one card of an opened pack, unique per pack and position,
  # written only by Game::Handlers::PackOpenedFeed in the opening's
  # transaction: `notable` pulls are Épique or better, a filler is the best
  # card of a pack that held none, kept so a quiet feed is never empty, and a
  # discovery is notable whatever its rarity. A repost is a card a player
  # shared, with no pack, written only by Game::Handlers::CardRepostedFeed.
  # A trade names its proposer and, as partner, its recipient, with the best
  # card each gave, unique per trade, written only by
  # Game::Handlers::TradeAccepted. A set entry sums up the tiers one
  # operation reached for a player (an opening, or one side of a trade), with
  # no card: the highest result, the count of sets, unique per player and
  # time, written only by Game::Handlers::SetTierFeed. Its `kind` is what the
  # feed's type filters read; visibility is not stored but asked when it is
  # shown.
  class FeedEntry < ApplicationRecord
    self.table_name = "game_feed_entries"

    # The lowest tier of a notable pull (Catalog::Rarity::TIERS: Épique).
    NOTABLE_TIER = 4

    # The kinds of entry (the database checks the same list); only pulls and
    # discoveries carry a pack and a position, only sets no card.
    KINDS = %w[pull discovery trade repost set].freeze

    # The tier rows the operation wrote beside the reached one (same player,
    # way, time and pack), one result per set at its highest tier, the
    # highest result first (the lowest set id on a tie), summed up in one
    # entry: rewritten whole on every event of the operation, so the last
    # one leaves it complete and a replay changes nothing.
    RECORD_SETS_SQL = <<~SQL.squish.freeze
      WITH reached AS (
        SELECT player_id, reached_by, reached_at, pack_id
          FROM game_set_tiers
         WHERE player_id = :player_id AND set_id = :set_id AND tier = :tier
      ),
      results AS (
        SELECT tiers.set_id, tiers.tier, tiers.reached_at, array_position(ARRAY[:tiers]::varchar[], tiers.tier) AS rank
          FROM game_set_tiers AS tiers
          JOIN reached ON tiers.player_id = reached.player_id AND tiers.reached_by = reached.reached_by
           AND tiers.reached_at = reached.reached_at AND tiers.pack_id IS NOT DISTINCT FROM reached.pack_id
      ),
      highest AS (
        SELECT set_id, tier, reached_at FROM results ORDER BY rank DESC, set_id LIMIT 1
      )
      INSERT INTO game_feed_entries (kind, player_id, set_id, tier, set_count, notable, occurred_at, created_at, updated_at)
      SELECT 'set', :player_id, highest.set_id, highest.tier, (SELECT COUNT(DISTINCT set_id) FROM results), TRUE,
             highest.reached_at, :now, :now
        FROM highest
          ON CONFLICT (player_id, occurred_at) WHERE kind = 'set' DO UPDATE
         SET set_id = excluded.set_id, tier = excluded.tier, set_count = excluded.set_count, updated_at = excluded.updated_at
       WHERE (game_feed_entries.set_id, game_feed_entries.tier, game_feed_entries.set_count)
             IS DISTINCT FROM (excluded.set_id, excluded.tier, excluded.set_count)
    SQL

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

    def self.record_trade(trade_id:, proposer_id:, recipient_id:, offer:, request:, rarities:, at:)
      card = best_card(offer, rarities)
      partner_card = best_card(request, rarities)
      return false unless card && partner_card

      row = { kind: "trade", player_id: proposer_id, partner_id: recipient_id, trade_id:, card_season_id: card,
        partner_card_season_id: partner_card, rarity: [ rarities[card], rarities[partner_card] ].max, notable: true,
        occurred_at: at, created_at: at, updated_at: at }
      insert_all([ row ], unique_by: :trade_id, record_timestamps: false).rows.any?
    end

    # Sums up in the feed the tiers of the operation that reached `tier` of
    # `set_id` for the player; nothing when no such tier row exists.
    def self.record_sets(player_id:, set_id:, tier:, now:)
      binds = { player_id:, set_id:, tier:, now:, tiers: SetTier::TIERS }
      connection.exec_update(sanitize_sql_array([ RECORD_SETS_SQL, binds ]), "Game::FeedEntry Record Sets")
    end

    def self.best_card(card_season_ids, rarities)
      card_season_ids.select { rarities[it] }.min_by { |id| [ -rarities[id], id ] }
    end
    private_class_method :best_card
  end
end
