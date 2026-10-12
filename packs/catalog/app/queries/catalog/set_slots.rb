module Catalog
  # One set of a season, found by its kind and key (AD-15: never by id), and
  # its card-seasons in slot order (by membership position, then membership
  # id), in one query; nil when the season holds no set of that kind and
  # key. The set is answered as a SetRef (kind, key, params), enough for a
  # screen to name it.
  #
  #   Catalog::SetSlots.call(season_id: season.id, kind: "theme", key: "rpg")
  #   # => Slots(set: SetRef(kind: "theme", key: "rpg", params: { … }), card_season_ids: [ 12, 7, … ]) | nil
  module SetSlots
    SetRef = Data.define(:kind, :key, :params)
    Slots = Data.define(:set, :card_season_ids)

    def self.call(season_id:, kind:, key:)
      rows = Set.where(season_id:, kind: kind.to_s, key: key.to_s)
        .left_joins(:memberships)
        .order(Arel.sql("catalog_set_memberships.position, catalog_set_memberships.id"))
        .pluck(:kind, :key, :params, Arel.sql("catalog_set_memberships.card_season_id"))
      return if rows.empty?

      set_kind, set_key, params = rows.first
      Slots.new(set: SetRef.new(kind: set_kind, key: set_key, params:), card_season_ids: rows.filter_map(&:last))
    end
  end
end
