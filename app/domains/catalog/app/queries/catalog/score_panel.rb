module Catalog
  module ScorePanel
    PERCENTILES = [ 10, 50, 90, 99 ].freeze
    EXTREMES = 10

    Panel = Data.define(:verdict, :card_count, :percentiles, :min, :max, :score_version_verdict, :sources_verdict, :tier_verdict,
      :tiers, :top, :bottom, :themes, :ufo_count, :set_counts, :classification_verdict, :unclassified_count, :ufo_verdict,
      :rescore_verdict) do
      def empty_season? = verdict == :empty_season

      def ufo_share = ufo_count && card_count.positive? ? ufo_count.fdiv(card_count) : nil

      def ufo_share_over_limit? = ufo_share.to_f > Themes::UFO_SHARE_LIMIT
    end
    Tier = Data.define(:tier, :card_count, :threshold)
    Entry = Data.define(:card_id, :title, :rating, :prestige_score)
    Theme = Data.define(:theme, :card_count)

    def self.empty_season
      Panel.new(verdict: :empty_season, **Panel.members.excluding(:verdict).index_with(nil))
    end

    def self.build(rows, tiers:, theme_counts:, ufo_count:, set_counts:, score_version_verdict: nil, sources_verdict: nil,
                   classification_verdict: nil, unclassified_count: nil, ufo_verdict: nil, rescore_verdict: nil)
      ranked_asc = rows.map(&:prestige_score).sort
      top = rows.sort_by { |row| [ -row.prestige_score, row.card_id ] }.first(EXTREMES)
      bottom = rows.sort_by { |row| [ row.prestige_score, row.card_id ] }.first(EXTREMES)
      titles = CardText.where(card_id: (top + bottom).map(&:card_id).uniq, locale: "en").pluck(:card_id, :title).to_h

      Panel.new(
        verdict: nil,
        card_count: rows.size,
        percentiles: PERCENTILES.index_with { |p| ranked_asc[((p * rows.size) + 99) / 100 - 1] },
        min: ranked_asc.first,
        max: ranked_asc.last,
        score_version_verdict:,
        sources_verdict:,
        tier_verdict: tiers ? nil : :empty_tier,
        tiers:,
        top: entries(top, titles),
        bottom: entries(bottom, titles),
        themes: theme_counts.map { |theme, card_count| Theme.new(theme:, card_count:) }.sort_by { |theme| [ -theme.card_count, theme.theme ] },
        ufo_count:,
        set_counts:,
        classification_verdict:,
        unclassified_count:,
        ufo_verdict:,
        rescore_verdict:
      )
    end

    def self.entries(rows, titles)
      rows.map { |row| Entry.new(card_id: row.card_id, title: titles[row.card_id], rating: row.rating, prestige_score: row.prestige_score) }
    end

    private_class_method :entries
  end
end
