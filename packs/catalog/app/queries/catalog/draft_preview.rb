module Catalog
  # What publishing the draft season now would produce, for calibrating the
  # prestige formula, the tier shares and the tome size before a season is
  # published (CAP-3, AD-5; epic 2, story 2.8). Reads the draft without a
  # lock and writes nothing; uses the same rules as PublishSeason
  # (RarityThresholds, Dust, SetBuilder), so publishing a draft unchanged
  # since gives the tier sizes and set counts shown here.
  #
  # Two queries at any size: the draft's rows (SeasonRows, the draft read in
  # the same query) and the English titles of the highest and lowest cards.
  # A draft with no card-season costs a second query to tell it from no
  # draft at all.
  #
  #   Catalog::DraftPreview.call
  #   # => nil (no draft) | Preview(verdict: :empty_season) | Preview(…)
  module DraftPreview
    # Nearest-rank percentiles of the prestige scores.
    PERCENTILES = [ 10, 50, 90, 99 ].freeze
    # How many of the highest and of the lowest cards are listed.
    EXTREMES = 10

    # `verdict` is :empty_season (and every other field nil) for a draft
    # with no card-season, nil otherwise. `tier_verdict` is :empty_tier (and
    # `tiers` nil) when a tier would hold no card.
    #
    # - `percentiles`: { 10 => score, 50 => …, 90 => …, 99 => … }
    # - `tiers`: [ Tier(tier, card_count, threshold) ], gold first; steel's
    #   threshold is nil
    # - `dust`: { 0 => count, …, 4 => count }, every level present
    # - `top`, `bottom`: [ Entry ], the highest scores first, the lowest first
    # - `genres`: [ Genre(genre, card_count, tome_count) ], the most cards
    #   first, then by genre; genre nil for the cards without one, last
    # - `set_counts`: { "publisher" => n, "tome" => n, "best_of_year" => n }
    Preview = Data.define(:verdict, :card_count, :percentiles, :min, :max, :tier_verdict, :tiers,
      :dust, :top, :bottom, :genres, :set_counts) do
      def empty_season? = verdict == :empty_season
    end
    Tier = Data.define(:tier, :card_count, :threshold)
    Entry = Data.define(:card_id, :title, :rating, :prestige_score)
    Genre = Data.define(:genre, :card_count, :tome_count)

    def self.call(on: Time.current.utc.to_date)
      rows = SeasonRows.call(Season.draft.select(:id))
      if rows.empty?
        return Season.draft.exists? ? Preview.new(verdict: :empty_season, **Preview.members.excluding(:verdict).index_with(nil)) : nil
      end

      scores = rows.map(&:prestige_score)
      ranked_asc = scores.sort
      top = rows.sort_by { |row| [ -row.prestige_score, row.card_id ] }.first(EXTREMES)
      bottom = rows.sort_by { |row| [ row.prestige_score, row.card_id ] }.first(EXTREMES)
      titles = CardText.where(card_id: (top + bottom).map(&:card_id).uniq, locale: "en").pluck(:card_id, :title).to_h
      tomes = SetBuilder.tomes(rows)
      tiers = tiers_of(scores)

      Preview.new(
        verdict: nil,
        card_count: rows.size,
        percentiles: PERCENTILES.index_with { |p| ranked_asc[((p * rows.size) + 99) / 100 - 1] },
        min: ranked_asc.first,
        max: ranked_asc.last,
        tier_verdict: tiers ? nil : :empty_tier,
        tiers:,
        dust: dust_of(rows, on),
        top: entries(top, titles),
        bottom: entries(bottom, titles),
        genres: genres_of(rows, tomes),
        set_counts: { "publisher" => SetBuilder.publishers(rows).size, "tome" => tomes.size, "best_of_year" => SetBuilder.best_of_year(rows).size }
      )
    end

    # Each tier's card count and threshold, gold first, as PublishSeason
    # would cut them; nil when a tier would hold no card.
    def self.tiers_of(scores)
      tiers = RarityThresholds.tiers(scores)
      return nil if tiers.nil?

      thresholds = RarityThresholds.thresholds(scores)
      counts = tiers.tally
      Rarity::TIERS.keys.reverse.map { |tier| Tier.new(tier:, card_count: counts.fetch(tier), threshold: thresholds[tier]) }
    end

    def self.dust_of(rows, on)
      counts = rows.map { |row| Dust.level_for(row.release_date, on:) }.tally
      Dust::LEVELS.keys.index_with { |level| counts.fetch(level, 0) }
    end

    def self.entries(rows, titles)
      rows.map { |row| Entry.new(card_id: row.card_id, title: titles[row.card_id], rating: row.rating, prestige_score: row.prestige_score) }
    end

    def self.genres_of(rows, tomes)
      tome_counts = tomes.map { |set| set[:params].fetch("genre") }.tally
      rows.group_by { |row| row.genres.first }
        .map { |genre, members| Genre.new(genre:, card_count: members.size, tome_count: genre ? tome_counts.fetch(genre, 0) : 0) }
        .sort_by { |genre| [ genre.genre.nil? ? 1 : 0, -genre.card_count, genre.genre.to_s ] }
    end

    private_class_method :tiers_of, :dust_of, :entries, :genres_of
  end
end
