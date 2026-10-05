module Game
  # The hub's "Progression des sets" (DESIGN.md, Set progress row): up to
  # `limit` sets of the season with the distinct cards the player holds of
  # each and its size. First the sets the player has started, those in
  # progress before the complete ones, then by share owned (descending),
  # cards owned (descending) and id; then, to fill up to `limit`, sets not
  # started yet at 0, tomes first, then by id. A nil player (a visitor) gets
  # the fill only.
  #
  # Reads the player's holdings joined to the season's memberships (AD-2:
  # Game reads Catalog) and the sizes of the sets they have started, in one
  # query; then the sets themselves, and the fill with its sizes. Never
  # aggregates the whole season.
  #
  #   Game::HubSets.call(player, season:) # => [ Row(set: Catalog::Set, owned: 3, total: 50), … ]
  module HubSets
    Row = Data.define(:set, :owned, :total)

    STARTED_SQL = <<~SQL.squish.freeze
      WITH owned AS (
        SELECT catalog_set_memberships.set_id, COUNT(*) AS owned
          FROM game_holdings
          JOIN catalog_set_memberships ON catalog_set_memberships.card_season_id = game_holdings.card_season_id
          JOIN catalog_sets ON catalog_sets.id = catalog_set_memberships.set_id
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
           AND catalog_sets.season_id = :season_id
         GROUP BY catalog_set_memberships.set_id
      ), progress AS (
        SELECT owned.set_id, owned.owned,
               (SELECT COUNT(*) FROM catalog_set_memberships AS members WHERE members.set_id = owned.set_id) AS total
          FROM owned
      )
      SELECT set_id, owned, total FROM progress
       ORDER BY owned >= total, owned::numeric / total DESC, owned DESC, set_id
       LIMIT :limit
    SQL

    def self.call(player, season:, limit: 4)
      return [] if season.nil? || limit <= 0

      rows = started(player, season, limit)
      rows + fill(season, limit - rows.size, exclude: rows.map { |row| row.set.id })
    end

    def self.started(player, season, limit)
      return [] if player.nil?

      progress = Holding.connection.select_rows(
        Holding.sanitize_sql_array([ STARTED_SQL, { player_id: player.id, season_id: season.id, limit: } ]), "Game::HubSets"
      )
      return [] if progress.empty?

      sets = Catalog::Set.where(id: progress.map(&:first)).index_by(&:id)
      progress.map { |set_id, owned, total| Row.new(set: sets.fetch(set_id.to_i), owned: owned.to_i, total: total.to_i) }
    end
    private_class_method :started

    def self.fill(season, count, exclude:)
      return [] if count <= 0

      sets = Catalog::Set.where(season_id: season.id).where.not(id: exclude)
        .order(Arel.sql("catalog_sets.kind = 'tome' DESC, catalog_sets.id")).limit(count).to_a
      totals = Catalog::SetTotals.call(sets.map(&:id))
      sets.map { |set| Row.new(set:, owned: 0, total: totals.fetch(set.id, 0)) }
    end
    private_class_method :fill
  end
end
