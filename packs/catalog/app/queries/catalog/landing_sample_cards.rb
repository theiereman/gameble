module Catalog
  module LandingSampleCards
    CACHE_LIFETIME = 10.minutes

    def self.call(locale:)
      season = PublishedSeason.call
      return empty if season.nil?

      Rails.cache.fetch([ "catalog/landing_sample_cards", CardView.members.join(","), season.id, locale.to_s ], expires_in: CACHE_LIFETIME) do
        read(season, locale)
      end
    end

    def self.empty
      Rarity::TIERS.values.index_with { nil }
    end

    def self.read(season, locale)
      ids = top_card_season_ids(season)
      views = CardViews.call(ids.values, locale:)
      empty.merge(ids.to_h { |tier, id| [ Rarity::TIERS.fetch(tier), views[id] ] })
    end

    def self.top_card_season_ids(season)
      CardSeason.where(season_id: season.id).where.not(rarity: nil)
        .order(:rarity, prestige_score: :desc, id: :asc)
        .pluck(Arel.sql("DISTINCT ON (catalog_card_seasons.rarity) catalog_card_seasons.rarity AS tier"), :id)
        .to_h
    end

    private_class_method :empty, :read, :top_card_season_ids
  end
end
