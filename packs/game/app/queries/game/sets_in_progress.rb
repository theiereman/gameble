module Game
  module SetsInProgress
    SQL = <<~SQL.squish.freeze
      WITH held AS (#{HeldGames::SQL}),
      latest AS (SELECT MAX(held.gained_at) AS gained_at FROM held),
      progress AS (
        SELECT members.set_id, COUNT(*) AS held, MAX(held.gained_at) AS gained_at
          FROM held
          JOIN catalog_card_seasons AS member ON member.card_id = held.card_id AND member.season_id = :season_id
          JOIN catalog_set_memberships AS members ON members.card_season_id = member.id
         GROUP BY members.set_id
      )
      SELECT progress.set_id, progress.held,
             (SELECT COUNT(*) FROM catalog_set_memberships AS everyone WHERE everyone.set_id = progress.set_id) AS total,
             (SELECT json_object_agg(tiers.tier, tiers.required) FROM catalog_set_tiers AS tiers WHERE tiers.set_id = progress.set_id) AS tiers,
             COALESCE(progress.gained_at = latest.gained_at, FALSE) AS just,
             EXISTS (
               SELECT 1 FROM game_set_tiers AS recorded
                WHERE recorded.player_id = :player_id AND recorded.set_id = progress.set_id
                  AND recorded.reached_at = latest.gained_at
             ) AS reached_now,
             progress.gained_at,
             (
               SELECT completion.reached_at FROM game_set_tiers AS completion
                WHERE completion.player_id = :player_id AND completion.set_id = progress.set_id AND completion.tier = 'complete'
             ) AS completed_at
        FROM progress CROSS JOIN latest
    SQL

    def self.call(player, season:)
      return {} if player.nil? || season.nil?

      result = Holding.connection.select_all(Holding.sanitize_sql_array([ SQL, { player_id: player.id, season_id: season.id } ]), "Game::SetsInProgress")
      result.cast_values.to_h do |set_id, held, total, tiers, just, reached_now, gained_at, completed_at|
        standing = SetStanding.new(set_id:, held:, total:, tiers: tier_hash(tiers), just:, reached_now:, gained_at:, completed_at:)
        [ set_id, standing ]
      end
    end

    def self.tier_hash(value)
      (value.is_a?(String) ? JSON.parse(value) : value || {}).transform_values(&:to_i)
    end
    private_class_method :tier_hash
  end
end
