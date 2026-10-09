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
    #
    # - `percentiles`: { 10 => score, 50 => …, 90 => …, 99 => … }
    # - `tiers`: [ Tier(tier, card_count, threshold) ], legendary first; common's
    #   threshold is nil
    # - `top`, `bottom`: [ Entry ], the highest scores first, the lowest first
    # - `genres`: [ Genre(genre, card_count, tome_count) ], the most cards
    #   first, then by genre; genre nil for the cards without one, last
    # - `set_counts`: { "publisher" => n, "tome" => n, "best_of_year" => n }
    Panel = Data.define(:verdict, :card_count, :percentiles, :min, :max, :score_version_verdict, :tier_verdict, :tiers,
      :top, :bottom, :genres, :set_counts) do
      def empty_season? = verdict == :empty_season
    end
    Tier = Data.define(:tier, :card_count, :threshold)
    Entry = Data.define(:card_id, :title, :rating, :prestige_score)
    Genre = Data.define(:genre, :card_count, :tome_count)

    def self.empty_season
      Panel.new(verdict: :empty_season, **Panel.members.excluding(:verdict).index_with(nil))
    end

    def self.build(rows, tiers:, tome_counts:, set_counts:, score_version_verdict: nil)
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
        tier_verdict: tiers ? nil : :empty_tier,
        tiers:,
        top: entries(top, titles),
        bottom: entries(bottom, titles),
        genres: genres_of(rows, tome_counts),
        set_counts:
      )
    end

    def self.entries(rows, titles)
      rows.map { |row| Entry.new(card_id: row.card_id, title: titles[row.card_id], rating: row.rating, prestige_score: row.prestige_score) }
    end

    def self.genres_of(rows, tome_counts)
      led = rows.group_by { |row| row.genres.first }
      (tome_counts.keys - led.keys).each { |genre| led[genre] = [] }
      led.map { |genre, members| Genre.new(genre:, card_count: members.size, tome_count: genre ? tome_counts.fetch(genre, 0) : 0) }
        .sort_by { |genre| [ genre.genre.nil? ? 1 : 0, -genre.card_count, genre.genre.to_s ] }
    end

    private_class_method :entries, :genres_of
  end
end
