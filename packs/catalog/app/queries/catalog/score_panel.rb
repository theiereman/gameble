module Catalog
  module ScorePanel
    # Nearest-rank percentiles of the prestige scores.
    PERCENTILES = [ 10, 50, 90, 99 ].freeze
    # How many of the highest and of the lowest cards are listed.
    EXTREMES = 10

    # `verdict` is :empty_season (and every other field nil) for a season
    # with no card-season, nil otherwise. `tier_verdict` is :empty_tier (and
    # `tiers` nil) when a tier would hold no card. `score_version_verdict` is
    # :mixed_score_versions when a draft's scores come from two formulas
    # (ScoreVersions), the rest still shown so the skew can be seen.
    # `sources_verdict` is :unfilled_sources when a draft holds a card
    # imported before its sources were stored (PublishSeason refuses it).
    #
    # - `percentiles`: { 10 => score, 50 => …, 90 => …, 99 => … }
    # - `tiers`: [ Tier(tier, card_count, threshold) ], legendary first; common's
    #   threshold is nil
    # - `top`, `bottom`: [ Entry ], the highest scores first, the lowest first
    # - `themes`: [ Theme(theme, card_count) ], each theme set's cards, the
    #   most first, then by theme
    # - `ufo_count`: the cards in the UFOs; nil for a season published
    #   before themes
    # - `set_counts`: { kind => n }
    Panel = Data.define(:verdict, :card_count, :percentiles, :min, :max, :score_version_verdict, :sources_verdict, :tier_verdict,
      :tiers, :top, :bottom, :themes, :ufo_count, :set_counts) do
      def empty_season? = verdict == :empty_season

      # The UFOs' share of the cards, from 0 to 1; nil without UFO count.
      def ufo_share = ufo_count && card_count.positive? ? ufo_count.fdiv(card_count) : nil

      def ufo_share_over_limit? = ufo_share.to_f > Themes::UFO_SHARE_LIMIT
    end
    Tier = Data.define(:tier, :card_count, :threshold)
    Entry = Data.define(:card_id, :title, :rating, :prestige_score)
    Theme = Data.define(:theme, :card_count)

    def self.empty_season
      Panel.new(verdict: :empty_season, **Panel.members.excluding(:verdict).index_with(nil))
    end

    # `theme_counts` is { theme => card count }.
    def self.build(rows, tiers:, theme_counts:, ufo_count:, set_counts:, score_version_verdict: nil, sources_verdict: nil)
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
        set_counts:
      )
    end

    def self.entries(rows, titles)
      rows.map { |row| Entry.new(card_id: row.card_id, title: titles[row.card_id], rating: row.rating, prestige_score: row.prestige_score) }
    end

    private_class_method :entries
  end
end
