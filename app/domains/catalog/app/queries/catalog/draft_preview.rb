module Catalog
  module DraftPreview
    def self.call
      rows = SeasonRows.call(Season.draft.select(:id))
      return nil if rows.empty? && !Season.draft.exists?

      of(rows)
    end

    def self.of(rows)
      return ScorePanel.empty_season if rows.empty?

      theme_keys = Themes.keys
      themes = SetBuilder.themes(rows, theme_keys:)
      franchises = SetBuilder.franchises(rows)
      studios = SetBuilder.studios(rows)
      hall_of_fame = SetBuilder.hall_of_fame(rows)
      ufos = SetBuilder.ufos(rows, theme_keys:)
      classification = Themes.classification
      unclassified = classification.unclassified_in(rows)
      ufo_count = ufos.sum { |set| set[:members].size }
      ScorePanel.build(rows,
        tiers: tiers_of(rows.map(&:prestige_score)),
        theme_counts: themes.to_h { |set| [ set[:key], set[:members].size ] },
        ufo_count:,
        set_counts: { "theme" => themes.size, "franchise" => franchises.size, "studio" => studios.size,
          "hall_of_fame" => hall_of_fame.size, "ufo" => ufos.size },
        score_version_verdict: ScoreVersions.mixed?(rows) ? :mixed_score_versions : nil,
        sources_verdict: UnfilledSources.any?(rows, theme_keys:) ? :unfilled_sources : nil,
        classification_verdict: unclassified.empty? ? nil : :unclassified_tags,
        unclassified_count: unclassified.size,
        ufo_verdict: Themes.ufo_share_over_limit?(ufo_count, rows.size) ? :ufo_share_over_limit : nil,
        rescore_verdict: classification.stale?(rows) ? :rescore_needed : nil)
    end

    def self.tiers_of(scores)
      tiers = RarityThresholds.tiers(scores)
      return nil if tiers.nil?

      thresholds = RarityThresholds.thresholds(scores)
      counts = tiers.tally
      Rarity::TIERS.keys.reverse.map { |tier| ScorePanel::Tier.new(tier:, card_count: counts.fetch(tier), threshold: thresholds[tier]) }
    end

    private_class_method :tiers_of
  end
end
