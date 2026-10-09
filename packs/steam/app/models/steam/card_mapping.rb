module Steam
  # Maps a game a run carried through every step (Steam::App.ready_by) onto
  # the keywords of Catalog::UpsertDraftCard (AD-4): plain Ruby values only
  # (String, Date, Integer, Float, Array, Hash), so Catalog never sees a
  # Steam record. `tag_names` is { tagid => English name } (Steam::Tag). The
  # genres are the game's listed genre tags, most-voted first
  # (Steam::GenreTags): Catalog puts the card in the tome of the first.
  #
  # A game without a review score or count cannot be scored: refused with
  # NO_REVIEWS, without calling Catalog. A score outside 0–100 or a count
  # below 1 (a row stored before Steam::ReviewPolicy refused such values) is
  # refused with INVALID_REVIEWS, so Steam::PrestigeScore never raises.
  #
  #   Steam::CardMapping.call(app, tag_names: { 19 => "Action" })
  #   # => Success({ source_key: "steam:620", ... }) | Failure(:no_reviews) | Failure(:invalid_reviews)
  module CardMapping
    extend Dry::Monads[:result]

    NO_REVIEWS = :no_reviews
    INVALID_REVIEWS = :invalid_reviews
    SOURCE_PREFIX = "steam:".freeze

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
        genres: GenreTags.call(app.tag_ids),
        tags: tag_keys(app.tag_ids, tag_names),
        prestige_score: PrestigeScore.call(percent_positive: app.review_percent_positive, review_count: app.review_count),
        prestige_score_version: PrestigeScore::VERSION,
        rating: app.review_percent_positive
      )
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
