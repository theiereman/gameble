module Steam
  module CardMapping
    extend Dry::Monads[:result]

    NO_REVIEWS = :no_reviews
    INVALID_REVIEWS = :invalid_reviews
    SOURCE_PREFIX = "steam:".freeze
    TOP_TAGS = Catalog::Themes::TOP_TAGS

    def self.call(app, tag_names:, classification: Catalog::Themes.classification)
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
        genres: genres(app.tag_ids, tag_names, classification),
        tags: tag_keys(app.tag_ids, tag_names),
        prestige_score: PrestigeScore.call(percent_positive: app.review_percent_positive, review_count: app.review_count),
        prestige_score_version: PrestigeScore::VERSION,
        rating: app.review_percent_positive,
        review_count: app.review_count
      )
    end

    def self.sources(app, tag_names:, classification: Catalog::Themes.classification)
      {
        source_key: source_key(app.appid),
        developers: app.developers,
        franchises: app.franchises,
        genres: genres(app.tag_ids, tag_names, classification),
        review_count: app.review_count&.then { |count| count if count >= 1 }
      }
    end

    def self.genres(tag_ids, tag_names, classification)
      Catalog::Themes.of(tag_keys(tag_ids, tag_names).first(TOP_TAGS), classification)
    end

    def self.source_key(appid)
      "#{SOURCE_PREFIX}#{appid}"
    end

    def self.tag_keys(tag_ids, tag_names)
      Array(tag_ids).filter_map { |tagid| tag_names[tagid] }
        .map { |name| Catalog::TagKey.of(name) }
        .reject(&:blank?)
        .uniq
    end
  end
end
