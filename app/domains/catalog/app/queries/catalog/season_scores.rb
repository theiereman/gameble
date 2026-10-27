module Catalog
  module SeasonScores
    Scores = Data.define(:number, :status, :published_at, :score_versions, :panel) do
      def draft? = status == "draft"
      def published? = status == "published"
    end

    def self.call(number)
      season = Season.find_by(number:)
      return nil if season.nil?

      rows = SeasonRows.call(season.id)
      Scores.new(
        number: season.number,
        status: season.status,
        published_at: season.published_at,
        score_versions: score_versions_of(rows),
        panel: season.published? ? published_panel(season.id, rows) : DraftPreview.of(rows)
      )
    end

    def self.score_versions_of(rows)
      unversioned, versioned = rows.map(&:prestige_score_version).uniq.partition(&:nil?)
      unversioned + versioned.sort
    end

    def self.published_panel(season_id, rows)
      kinds = Set.where(season_id:).group(:kind).count
      members = SetMembership.joins(:set).where(catalog_sets: { season_id:, kind: %w[theme ufo] })
        .group("catalog_sets.kind", "catalog_sets.key").count
      ScorePanel.build(rows,
        tiers: stored_tiers(season_id),
        theme_counts: members.filter_map { |(kind, key), count| [ key, count ] if kind == "theme" }.to_h,
        ufo_count: kinds.key?("theme") || kinds.key?("ufo") ? members.sum { |(kind, _), count| kind == "ufo" ? count : 0 } : nil,
        set_counts: Set.kinds.keys.index_with { |kind| kinds.fetch(kind, 0) })
    end

    def self.stored_tiers(season_id)
      stored = CardSeason.where(season_id:).where.not(rarity: nil).group(:rarity)
        .pluck(:rarity, Arel.sql("COUNT(*)"), Arel.sql("MIN(prestige_score)"))
        .to_h { |name, count, lowest| [ CardSeason.rarities.fetch(name), [ count, lowest ] ] }
      Rarity::TIERS.keys.reverse.map do |tier|
        count, lowest = stored.fetch(tier, [ 0, nil ])
        ScorePanel::Tier.new(tier:, card_count: count, threshold: tier == RarityThresholds::COMMON ? nil : lowest)
      end
    end

    private_class_method :score_versions_of, :published_panel, :stored_tiers
  end
end
