module Game
  module ProfileTitles
    Title = Data.define(:kind, :key, :params, :rank, :season_number)

    RANK_OF_TIER = { "bronze" => "apprentice", "silver" => "adept", "gold" => "master" }.freeze
    RANKS = [ *Catalog::TierTable::RANKS, Catalog::TierTable::COMPLETE ].freeze

    SQL = <<~SQL.squish.freeze
      SELECT DISTINCT ON (sets.kind, sets.key, titled.rank) sets.kind, sets.key, sets.params, titled.rank, seasons.number
        FROM (SELECT set_id, CASE tier #{RANK_OF_TIER.map { |tier, rank| "WHEN '#{tier}' THEN '#{rank}'" }.join(" ")} ELSE tier END AS rank
                FROM game_set_tiers WHERE player_id = :player_id) AS titled
        JOIN catalog_sets AS sets ON sets.id = titled.set_id
        JOIN catalog_seasons AS seasons ON seasons.id = sets.season_id
       ORDER BY sets.kind, sets.key, titled.rank, seasons.number DESC
    SQL

    def self.call(player)
      rows = SetTier.connection.select_rows(SetTier.sanitize_sql_array([ SQL, { player_id: player.id } ]), "Game::ProfileTitles")
      titles = rows.map { |kind, key, params, rank, number| Title.new(kind:, key:, params: JSON.parse(params), rank:, season_number: number) }
      titles.sort_by { |title| [ -RANKS.index(title.rank), -title.season_number, title.kind, title.key ] }
    end
  end
end
