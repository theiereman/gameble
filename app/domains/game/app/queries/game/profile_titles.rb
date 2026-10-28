module Game
  module ProfileTitles
    Title = Data.define(:kind, :key, :params, :rank, :season_number)

    RANK_OF_TIER = { "bronze" => "apprentice", "silver" => "adept", "gold" => "master" }.freeze
    RANKS = [ *Catalog::TierTable::RANKS, Catalog::TierTable::COMPLETE ].freeze

    SQL = <<~SQL.squish.freeze
      SELECT DISTINCT ON (titled.player_id, sets.kind, sets.key, titled.rank) titled.player_id, sets.kind, sets.key, sets.params, titled.rank, seasons.number
        FROM (SELECT player_id, set_id, CASE tier #{RANK_OF_TIER.map { |tier, rank| "WHEN '#{tier}' THEN '#{rank}'" }.join(" ")} ELSE tier END AS rank
                FROM game_set_tiers WHERE player_id IN (:player_ids)) AS titled
        JOIN catalog_sets AS sets ON sets.id = titled.set_id
        JOIN catalog_seasons AS seasons ON seasons.id = sets.season_id
       ORDER BY titled.player_id, sets.kind, sets.key, titled.rank, seasons.number DESC
    SQL

    def self.call(player)
      for_players([ player ]).fetch(player.id, [])
    end

    def self.for_players(players)
      rows = SetTier.connection.select_rows(SetTier.sanitize_sql_array([ SQL, { player_ids: players.map(&:id) } ]), "Game::ProfileTitles")
      rows.group_by(&:first).transform_values do |player_rows|
        titles = player_rows.map { |_, kind, key, params, rank, number| Title.new(kind:, key:, params: JSON.parse(params), rank:, season_number: number) }
        titles.sort_by { |title| [ -RANKS.index(title.rank), -title.season_number, title.kind, title.key ] }
      end
    end
  end
end
