module Game
  module RarityLegend
    Figures = Data.define(:owned, :total) do
      def +(other) = Figures.new(owned: owned + other.owned, total: total + other.total)
    end

    NONE = Figures.new(owned: 0, total: 0)

    Row = Data.define(:rarity, :season, :overall)

    Legend = Data.define(:rows) do
      def totals = Row.new(rarity: nil, season: rows.sum(NONE, &:season), overall: rows.sum(NONE, &:overall))
    end

    SQL = <<~SQL.squish.freeze
      WITH current_season AS (SELECT id FROM catalog_seasons WHERE status = 'published' ORDER BY number DESC LIMIT 1)
      SELECT catalog_card_seasons.rarity AS tier,
             COUNT(game_holdings.id) FILTER (WHERE catalog_card_seasons.season_id = (SELECT id FROM current_season)) AS season_owned,
             COUNT(*) FILTER (WHERE catalog_card_seasons.season_id = (SELECT id FROM current_season)) AS season_total,
             COUNT(game_holdings.id) AS owned,
             COUNT(*) AS total
        FROM catalog_card_seasons
        JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id AND catalog_seasons.status = 'published'
        LEFT JOIN game_holdings ON game_holdings.card_season_id = catalog_card_seasons.id
             AND game_holdings.player_id = :player_id AND game_holdings.quantity > 0
       WHERE catalog_card_seasons.rarity IS NOT NULL
       GROUP BY catalog_card_seasons.rarity
    SQL

    def self.call(player)
      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ SQL, { player_id: player&.id } ]), "Game::RarityLegend")
      counts = rows.to_h { |tier, *figures| [ tier.to_i, figures.map(&:to_i) ] }
      Legend.new(rows: Catalog::Rarity::TIERS.map { |tier, rarity| row(rarity, counts.fetch(tier, [ 0, 0, 0, 0 ])) })
    end

    def self.row(rarity, (season_owned, season_total, owned, total))
      Row.new(rarity:, season: Figures.new(owned: season_owned, total: season_total), overall: Figures.new(owned:, total:))
    end
    private_class_method :row
  end
end
