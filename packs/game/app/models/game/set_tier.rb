module Game
  # A tier of a set a player reached: one row per player, set and tier,
  # unique in the database, with how it was reached (an opening's pack, or
  # a trade). Its insert decides that the tier's event is published, once;
  # a tier stays reached when cards leave.
  class SetTier < ApplicationRecord
    self.table_name = "game_set_tiers"

    TIERS = Catalog::SetTier::TIERS
    REACHED_BY = %w[pack trade].freeze

    # A tier's position among TIERS, joined as `tier_order`: what breaks a
    # tie between two tiers of one set asking the same count.
    TIER_ORDER_SQL = "unnest(ARRAY[:tiers]::varchar[]) WITH ORDINALITY AS tier_order (tier, position)".freeze

    # The published season's sets holding a game of the credited cards, in
    # any edition; a member counts when the player holds its game in any
    # season (Game::HeldGames). Every tier whose `required` the count meets
    # is inserted, and the rows inserted are answered, by set, then by the
    # count their tier asks. One statement, whatever the sets.
    RECORD_SQL = <<~SQL.squish.freeze
      WITH held AS (#{HeldGames::SQL}),
      candidates AS (
        SELECT DISTINCT members.set_id
          FROM catalog_card_seasons AS credited
          JOIN catalog_card_seasons AS published
            ON published.card_id = credited.card_id AND published.season_id = :season_id
          JOIN catalog_set_memberships AS members ON members.card_season_id = published.id
         WHERE credited.id IN (:card_season_ids)
      ),
      progress AS (
        SELECT members.set_id, COUNT(held.card_id) AS held
          FROM candidates
          JOIN catalog_set_memberships AS members ON members.set_id = candidates.set_id
          JOIN catalog_card_seasons AS member ON member.id = members.card_season_id
          LEFT JOIN held ON held.card_id = member.card_id
         GROUP BY members.set_id
      ),
      inserted AS (
        INSERT INTO game_set_tiers (player_id, set_id, tier, reached_by, pack_id, reached_at, created_at, updated_at)
        SELECT :player_id, progress.set_id, tiers.tier, :reached_by, :pack_id, :now, :now, :now
          FROM progress
          JOIN catalog_set_tiers AS tiers ON tiers.set_id = progress.set_id AND progress.held >= tiers.required
          JOIN #{TIER_ORDER_SQL} ON tier_order.tier = tiers.tier
         ORDER BY progress.set_id, tiers.required, tier_order.position
            ON CONFLICT (player_id, set_id, tier) DO NOTHING
        RETURNING set_id, tier
      )
      SELECT inserted.set_id, inserted.tier
        FROM inserted
        JOIN catalog_set_tiers AS tiers ON tiers.set_id = inserted.set_id AND tiers.tier = inserted.tier
        JOIN #{TIER_ORDER_SQL} ON tier_order.tier = inserted.tier
       ORDER BY inserted.set_id, tiers.required, tier_order.position
    SQL

    # Records the tiers the player reaches with `card_season_ids`, the cards
    # an operation has just credited to them, in its transaction: answers
    # the [set_id, tier] pairs reached for the first time, by set, then by
    # the count their tier asks.
    def self.record(player_id:, card_season_ids:, season_id:, reached_by:, pack_id:, now:)
      return [] if card_season_ids.empty?

      binds = { player_id:, card_season_ids: card_season_ids.uniq, season_id:, reached_by:, pack_id:, now:, tiers: TIERS }
      rows = connection.select_rows(sanitize_sql_array([ RECORD_SQL, binds ]), "Game::SetTier Record")
      rows.map { |set_id, tier| [ set_id.to_i, tier ] }
    end
  end
end
