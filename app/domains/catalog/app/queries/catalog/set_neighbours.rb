module Catalog
  module SetNeighbours
    Neighbours = Data.define(:set, :position, :total, :previous, :next)

    SQL = <<~SQL.squish.freeze
      SELECT ranked.kind, ranked.key, ranked.params, ranked.slot, ranked.total, ranked.previous_slug, ranked.next_slug FROM (
        SELECT membership.card_season_id, catalog_set.kind, catalog_set.key, catalog_set.params,
          ROW_NUMBER() OVER slots AS slot, COUNT(*) OVER () AS total,
          LAG(card.slug) OVER slots AS previous_slug, LEAD(card.slug) OVER slots AS next_slug
        FROM catalog_set_memberships membership
        JOIN catalog_sets catalog_set ON catalog_set.id = membership.set_id
        JOIN catalog_card_seasons card_season ON card_season.id = membership.card_season_id
        JOIN catalog_cards card ON card.id = card_season.card_id
        JOIN catalog_card_texts card_text ON card_text.card_id = card.id AND card_text.locale = :locale
        WHERE catalog_set.season_id = (SELECT season_id FROM catalog_card_seasons WHERE id = :id)
          AND catalog_set.kind = :kind AND catalog_set.key = :key AND card_season.rarity IS NOT NULL
        WINDOW slots AS (ORDER BY membership.position, membership.id)
      ) ranked
      WHERE ranked.card_season_id = :id
    SQL

    def self.call(card_season_id:, kind:, key:, locale:)
      sql = SetMembership.sanitize_sql_array([ SQL, { id: card_season_id, kind: kind.to_s, key: key.to_s, locale: locale.to_s } ])
      row = SetMembership.connection.select_all(sql, "Catalog::SetNeighbours").cast_values.first
      return if row.nil?

      set_kind, set_key, params, position, total, previous, following = row
      Neighbours.new(set: SetRef.new(kind: set_kind, key: set_key, params:), position:, total:,
        previous:, next: following)
    end
  end
end
