module Catalog
  # What publishing the draft season now would produce, for calibrating the
  # prestige formula, the tier shares and the themes before a season is
  # published: a ScorePanel. Reads the draft without a lock and writes
  # nothing; uses the same rules as PublishSeason (RarityThresholds,
  # SetBuilder), so publishing a draft unchanged since gives the tier sizes
  # and set counts shown here.
  #
  # Two queries at any size: the draft's rows (SeasonRows, the draft read in
  # the same query) and the English titles of the highest and lowest cards.
  # A draft with no card-season costs a second query to tell it from no
  # draft at all.
  #
  #   Catalog::DraftPreview.call
  #   # => nil (no draft) | Panel(verdict: :empty_season) | Panel(…)
  module DraftPreview
    def self.call
      rows = SeasonRows.call(Season.draft.select(:id))
      return nil if rows.empty? && !Season.draft.exists?

      of(rows)
    end

    def self.of(rows)
      return ScorePanel.empty_season if rows.empty?

      themes = SetBuilder.themes(rows)
      franchises = SetBuilder.franchises(rows)
      studios = SetBuilder.studios(rows)
      hall_of_fame = SetBuilder.hall_of_fame(rows)
      ufos = SetBuilder.ufos(rows)
      ScorePanel.build(rows,
        tiers: tiers_of(rows.map(&:prestige_score)),
        theme_counts: themes.to_h { |set| [ set[:key], set[:members].size ] },
        ufo_count: ufos.sum { |set| set[:members].size },
        set_counts: { "theme" => themes.size, "franchise" => franchises.size, "studio" => studios.size,
          "hall_of_fame" => hall_of_fame.size, "ufo" => ufos.size },
        score_version_verdict: ScoreVersions.mixed?(rows) ? :mixed_score_versions : nil,
        theme_verdict: unknown_theme?(rows) ? :unknown_theme : nil)
    end

    # Each tier's card count and threshold, legendary first, as PublishSeason
    # would cut them; nil when a tier would hold no card.
    def self.tiers_of(scores)
      tiers = RarityThresholds.tiers(scores)
      return nil if tiers.nil?

      thresholds = RarityThresholds.thresholds(scores)
      counts = tiers.tally
      Rarity::TIERS.keys.reverse.map { |tier| ScorePanel::Tier.new(tier:, card_count: counts.fetch(tier), threshold: thresholds[tier]) }
    end

    def self.unknown_theme?(rows)
      rows.any? { |row| row.genres.any? { |genre| !Themes.key?(genre) } }
    end

    private_class_method :tiers_of, :unknown_theme?
  end
end
