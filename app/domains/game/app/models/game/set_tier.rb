module Game
  class SetTier < ApplicationRecord
    self.table_name = "game_set_tiers"

    TIERS = Catalog::SetTier::TIERS
    REACHED_BY = %w[pack trade].freeze

    TIER_ORDER_SQL = "unnest(ARRAY[:tiers]::varchar[]) WITH ORDINALITY AS tier_order (tier, position)".freeze

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
        INSERT INTO game_set_tiers (player_id, set_id, tier, held, reached_by, pack_id, reached_at, created_at, updated_at)
        SELECT :player_id, progress.set_id, tiers.tier, progress.held, :reached_by, :pack_id, :now, :now, :now
          FROM progress
          JOIN catalog_set_tiers AS tiers ON tiers.set_id = progress.set_id AND progress.held >= tiers.required
          JOIN catalog_set_tiers AS complete ON complete.set_id = progress.set_id AND complete.tier = 'complete'
          JOIN #{TIER_ORDER_SQL} ON tier_order.tier = tiers.tier
         WHERE tiers.tier = 'complete' OR complete.required >= :smallest_tiered
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

    def self.record(player_id:, card_season_ids:, season_id:, reached_by:, pack_id:, now:)
      return [] if card_season_ids.empty?

      binds = { player_id:, card_season_ids: card_season_ids.uniq, season_id:, reached_by:, pack_id:, now:, tiers: TIERS,
                smallest_tiered: Catalog::TierTable::SMALLEST_TIERED }
      rows = connection.select_rows(sanitize_sql_array([ RECORD_SQL, binds ]), "Game::SetTier Record")
      rows.map { |set_id, tier| [ set_id.to_i, tier ] }
    end
  end
end
