module Game
  module RarityLegend
    Figures = Data.define(:owned, :total)

    Row = Data.define(:rarity, :season, :overall)

    Legend = Data.define(:rows, :totals)

    NO_GAMES = [ 0, 0, 0, 0 ].freeze
    EVERY_RARITY = nil

    SQL = <<~SQL.squish.freeze
      WITH current_season AS (SELECT id FROM catalog_seasons WHERE status = 'published' ORDER BY number DESC LIMIT 1),
           editions AS (
             SELECT catalog_card_seasons.rarity, catalog_card_seasons.card_id,
                    catalog_card_seasons.season_id = (SELECT id FROM current_season) AS this_season,
                    game_holdings.id IS NOT NULL AS held
               FROM catalog_card_seasons
               JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id AND catalog_seasons.status = 'published'
               LEFT JOIN game_holdings ON game_holdings.card_season_id = catalog_card_seasons.id
                    AND game_holdings.player_id = :player_id AND game_holdings.quantity > 0
              WHERE catalog_card_seasons.rarity IS NOT NULL
           )
      SELECT rarity AS tier,
             COUNT(DISTINCT card_id) FILTER (WHERE this_season AND held) AS season_owned,
             COUNT(DISTINCT card_id) FILTER (WHERE this_season) AS season_total,
             COUNT(DISTINCT card_id) FILTER (WHERE held) AS owned,
             COUNT(DISTINCT card_id) AS total
        FROM editions
       GROUP BY ROLLUP (rarity)
    SQL

    def self.call(player)
      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ SQL, { player_id: player&.id } ]), "Game::RarityLegend")
      counts = rows.to_h { |tier, *figures| [ tier&.to_i, figures.map(&:to_i) ] }
      Legend.new(
        rows: Catalog::Rarity::TIERS.map { |tier, rarity| row(rarity, counts.fetch(tier, NO_GAMES)) },
        totals: row(nil, counts.fetch(EVERY_RARITY, NO_GAMES))
      )
    end

    def self.row(rarity, (season_owned, season_total, owned, total))
      Row.new(rarity:, season: Figures.new(owned: season_owned, total: season_total), overall: Figures.new(owned:, total:))
    end
    private_class_method :row
  end
end
