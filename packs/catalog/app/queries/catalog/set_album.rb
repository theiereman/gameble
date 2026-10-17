module Catalog
  module SetAlbum
    Album = Data.define(:set, :members, :tiers)

    def self.call(season:, kind:, key:)
      set = Set.find_by(season_id: season.id, kind: kind.to_s, key: key.to_s)
      return if set.nil?

      Album.new(set:, members: members(set), tiers: SetTier.where(set_id: set.id).pluck(:tier, :required).to_h)
    end

    def self.members(set)
      SetMembership.where(set_id: set.id).joins(:card_season)
        .order(:position, :id)
        .pluck(:card_season_id, Arel.sql("catalog_card_seasons.card_id"))
    end
    private_class_method :members
  end
end
