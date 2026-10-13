module Steam
  # Maps a game a run carried through every step (Steam::App.ready_by) onto
  # the keywords of Catalog::UpsertDraftCard: plain Ruby values only
  # (String, Date, Integer, Float, Array, Hash), so Catalog never sees a
  # Steam record. `tag_names` is { tagid => English name } (Steam::Tag). The
  # genres are the themes (Catalog::Themes) of the game's TOP_TAGS
  # most-voted tags, most-voted first (Steam::DetailsPolicy keeps tag_ids
  # heaviest first): a tagid missing from `tag_names` keeps its place among
  # them, so the next tag never takes it.
  #
  # A game without a review score or count cannot be scored: refused with
  # NO_REVIEWS, without calling Catalog. A score outside 0–100 or a count
  # below 1 (a row stored before Steam::ReviewPolicy refused such values) is
  # refused with INVALID_REVIEWS, so Steam::PrestigeScore never raises.
  #
  #   Steam::CardMapping.call(app, tag_names: { 19 => "Action" })
  #   # => Success({ source_key: "steam:620", ... }) | Failure(:no_reviews) | Failure(:invalid_reviews)
  #
  # `sources` maps any detailed app onto a row of Catalog::FillCardSources,
  # for cards written before they carried their developers, franchises,
  # themes and review count; a review count below 1 maps to nil.
  #
  #   Steam::CardMapping.sources(app, tag_names: { 1664 => "Puzzle" })
  #   # => { source_key: "steam:620", developers: ["Valve"], franchises: ["Portal"], genres: ["puzzle"], review_count: 1000 }
  module CardMapping
    extend Dry::Monads[:result]

    NO_REVIEWS = :no_reviews
    INVALID_REVIEWS = :invalid_reviews
    SOURCE_PREFIX = "steam:".freeze
    # A game's themes come from this many of its most-voted tags.
    TOP_TAGS = 5

    def self.call(app, tag_names:)
      return Failure(NO_REVIEWS) if app.review_percent_positive.nil? || app.review_count.nil?
      return Failure(INVALID_REVIEWS) unless app.review_percent_positive.between?(0, 100) && app.review_count >= 1

      Success(
        source_key: source_key(app.appid),
        texts: {
          "en" => { title: app.name_en, short_description: app.short_description_en },
          "fr" => { title: app.name_fr, short_description: app.short_description_fr }
        },
        release_date: app.release_on,
        image_url: app.image_url,
        store_url: app.store_url,
        publisher: Array(app.publishers).first,
        developers: app.developers,
        franchises: app.franchises,
        genres: genres(app.tag_ids, tag_names),
        tags: tag_keys(app.tag_ids, tag_names),
        prestige_score: PrestigeScore.call(percent_positive: app.review_percent_positive, review_count: app.review_count),
        prestige_score_version: PrestigeScore::VERSION,
        rating: app.review_percent_positive,
        review_count: app.review_count
      )
    end

    def self.sources(app, tag_names:)
      {
        source_key: source_key(app.appid),
        developers: app.developers,
        franchises: app.franchises,
        genres: genres(app.tag_ids, tag_names),
        review_count: app.review_count&.then { |count| count if count >= 1 }
      }
    end

    def self.genres(tag_ids, tag_names)
      Catalog::Themes.of(Array(tag_ids).first(TOP_TAGS).filter_map { |tagid| tag_names[tagid] })
    end

    # The opaque key of the card of `appid` in Catalog.
    def self.source_key(appid)
      "#{SOURCE_PREFIX}#{appid}"
    end

    # The names of the game's tags, in its order, as keys: unknown tagids
    # dropped, names parameterized with `_` (parameterize keeps hyphens, so
    # they become `_` too: "Co-op" and "Co op" are both "co_op", kept once),
    # blank keys dropped.
    def self.tag_keys(tag_ids, tag_names)
      Array(tag_ids).filter_map { |tagid| tag_names[tagid] }
        .map { |name| name.parameterize(separator: "_", locale: :en).tr("-", "_").squeeze("_").delete_prefix("_").delete_suffix("_") }
        .reject(&:blank?)
        .uniq
    end
  end
end
