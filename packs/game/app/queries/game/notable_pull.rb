module Game
  # The hub's showcase (EXPERIENCE.md, Showcase): the player's latest notable
  # pull, a card of tier TIER or above of the published season. Among the
  # player's opened packs holding one, the most recently opened; in that
  # pack, the card of the highest tier, the first drawn on a tie. The pack's
  # cards are unnested with their draw position (AD-2: Game reads Catalog's
  # card-seasons). One query when the pull is among the RECENT latest opened
  # packs (the common case, read through the player_id index); only when it
  # is not, a second one over every opened pack. nil, without a query, for
  # nil (a visitor), and nil when nothing qualifies or no season is
  # published.
  #
  #   Game::NotablePull.call(player) # => card-season id | nil
  module NotablePull
    # The lowest tier shown (Catalog::Rarity::TIERS: Épique and above).
    TIER = 4

    # The latest opened packs looked at first.
    RECENT = 50

    # `:limit` NULL is no limit (Postgres reads LIMIT NULL as LIMIT ALL).
    SQL = <<~SQL.squish.freeze
      WITH opened AS (
        SELECT game_packs.id, game_packs.opened_at, game_packs.card_season_ids
          FROM game_packs
         WHERE game_packs.player_id = :player_id AND game_packs.opened_at IS NOT NULL
         ORDER BY game_packs.opened_at DESC, game_packs.id DESC
         LIMIT :limit)
      SELECT pulled.card_season_id
        FROM opened
        CROSS JOIN LATERAL unnest(opened.card_season_ids) WITH ORDINALITY AS pulled(card_season_id, position)
        JOIN catalog_card_seasons ON catalog_card_seasons.id = pulled.card_season_id
       WHERE catalog_card_seasons.rarity >= :tier
         AND catalog_card_seasons.season_id = (
           SELECT catalog_seasons.id FROM catalog_seasons
            WHERE catalog_seasons.status = 'published'
            ORDER BY catalog_seasons.number DESC LIMIT 1)
       ORDER BY opened.opened_at DESC, opened.id DESC, catalog_card_seasons.rarity DESC, pulled.position
       LIMIT 1
    SQL

    def self.call(player)
      return if player.nil?

      pull(player, RECENT) || pull(player, nil)
    end

    def self.pull(player, limit)
      sql = Pack.sanitize_sql_array([ SQL, { player_id: player.id, tier: TIER, limit: } ])
      Pack.connection.select_value(sql, "Game::NotablePull")&.to_i
    end
    private_class_method :pull
  end
end
