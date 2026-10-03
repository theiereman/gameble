module Catalog
  # Writes a card into the draft season (CAP-2, AD-5), whatever its source:
  # the card is keyed by an opaque source key the caller builds (AD-4).
  # Idempotent: the same source key again updates the card, its texts and its
  # card-season in place.
  #
  # The draft season is created when there is none (number MAX + 1) and is
  # locked FOR SHARE, so the season cannot be published under the upsert.
  # Card fields and texts are the card's identity and are updated in place
  # even when the card is in a published season; that season's card-season is
  # left as it is, and the draft gets its own. Every unique index met by a
  # concurrent writer is absorbed with a savepoint and a re-read.
  #
  # Publishes Catalog::DraftCardUpserted on every call, even when nothing
  # changed.
  #
  #   Catalog::UpsertDraftCard.new.call(
  #     source_key: "src:620", release_date: Date.new(2011, 4, 18),
  #     image_url: "https://…", store_url: "https://…",
  #     texts: { "en" => { title: "Portal 2", short_description: "…" }, "fr" => { title: "Portal 2" } },
  #     prestige_score: 0.97, rating: 98.0,
  #     publisher: "…", genres: %w[action], tags: %w[puzzle]
  #   )
  #   # => Success(card_season) | Failure(:missing_text) | Failure(:invalid_card)
  class UpsertDraftCard < ApplicationOperation
    # Tries at an insert that meets a unique index before giving up.
    ATTEMPTS = 3

    def call(source_key:, release_date:, image_url:, store_url:, texts:, prestige_score:, rating:,
             publisher: nil, genres: [], tags: [])
      card_attributes = step validate_card(source_key:, release_date:, image_url:, store_url:, publisher:, genres:, tags:)
      scores = step validate_scores(prestige_score:, rating:)
      texts = step validate_texts(texts)

      transaction do
        season = step draft_season
        card = step upsert_card(card_attributes, texts)
        card_season = step upsert_card_season(card, season, scores)
        step publish(
          DraftCardUpserted.new(data: { card_id: card.id, season_id: season.id, card_season_id: card_season.id }),
          stream_name: Season.stream_name(season.id)
        )
        card_season
      end
    end

    private

    # Genres name tomes (SetBuilder), so each must be a valid set key:
    # one malformed genre would otherwise stop the season's publication.
    def validate_card(source_key:, release_date:, image_url:, store_url:, publisher:, genres:, tags:)
      valid = [ source_key, image_url, store_url ].all? { |value| present_string?(value) } &&
        release_date.is_a?(Date) &&
        (publisher.nil? || publisher.is_a?(String)) &&
        [ genres, tags ].all? { |list| list.is_a?(Array) && list.all? { |item| present_string?(item) } } &&
        genres.all? { |genre| Set::KEY_FORMAT.match?(genre) }
      return Failure(:invalid_card) unless valid

      Success(source_key:, release_date:, image_url:, store_url:, publisher: publisher.presence, genres:, tags:)
    end

    # Scores are numbers as given, never parsed from strings.
    def validate_scores(prestige_score:, rating:)
      if real?(prestige_score) && real?(rating) && rating.between?(0, 100)
        Success(prestige_score:, rating:)
      else
        Failure(:invalid_card)
      end
    end

    # Texts in every locale, each with a title. A locale outside
    # CardText::LOCALES, or a title that is not a String, is a bad attribute;
    # a missing text, or a missing or blank title, is a missing text.
    def validate_texts(texts)
      return Failure(:invalid_card) unless texts.is_a?(Hash)

      texts = texts.transform_keys(&:to_s)
      return Failure(:invalid_card) unless (texts.keys - CardText::LOCALES).empty?

      CardText::LOCALES.to_h do |locale|
        text = texts[locale]
        return Failure(:missing_text) if text.nil?
        return Failure(:invalid_card) unless text.is_a?(Hash)

        text = text.transform_keys(&:to_sym)
        return Failure(:invalid_card) unless (text.keys - %i[title short_description]).empty?
        return Failure(:invalid_card) unless text[:title].nil? || text[:title].is_a?(String)
        return Failure(:missing_text) unless present_string?(text[:title])
        return Failure(:invalid_card) unless text[:short_description].nil? || text[:short_description].is_a?(String)

        [ locale, { title: text[:title], short_description: text[:short_description].presence } ]
      end.then { |valid_texts| Success(valid_texts) }
    end

    def present_string?(value)
      value.is_a?(String) && value.present?
    end

    def real?(value)
      value.is_a?(Numeric) && value.real? && value.finite?
    end

    # The draft season, locked FOR SHARE; created when there is none. Two
    # first upserts at once meet the one-draft or the number index: the loser
    # reads the winner's draft.
    def draft_season
      ATTEMPTS.times do
        season = find_draft_season || create_draft_season
        return Success(season) if season
      end
      raise ActiveRecord::RecordNotUnique, "no draft season after #{ATTEMPTS} attempts"
    end

    def find_draft_season
      Season.draft.lock("FOR SHARE").take
    end

    # The new draft is this transaction's own uncommitted row: nobody else
    # can see it, let alone publish it.
    def create_draft_season
      Season.transaction(requires_new: true) { Season.create!(status: :draft, number: Season.next_number) }
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    # The card of the source key, locked, updated in place; or a new card
    # with its texts, whose English title gives the slug.
    def upsert_card(attributes, texts)
      ATTEMPTS.times do
        card = find_card(attributes[:source_key])
        return update_card(card, attributes, texts) if card

        card = create_card(attributes, texts)
        return Success(card) if card
      end
      raise ActiveRecord::RecordNotUnique, "no card after #{ATTEMPTS} attempts"
    rescue ActiveRecord::RecordInvalid
      Failure(:invalid_card)
    end

    def find_card(source_key)
      Card.lock.find_by(source_key: source_key)
    end

    # The texts are built before the card is saved, so the slug sees the
    # English title. Meeting the source key index means another writer
    # created the card: the next attempt reads and updates it. Meeting the
    # slug index means another card took the slug: the next attempt picks
    # the next candidate.
    def create_card(attributes, texts)
      Card.transaction(requires_new: true) do
        card = Card.new(attributes)
        texts.each { |locale, text| card.texts.build(locale: locale, **text) }
        card.save!
        card
      end
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def update_card(card, attributes, texts)
      card.update!(attributes)
      texts.each { |locale, text| upsert_text(card, locale, text) }
      Success(card)
    end

    def upsert_text(card, locale, attributes)
      ATTEMPTS.times do
        text = find_text(card, locale)
        return text.update!(attributes) if text
        return if create_text(card, locale, attributes)
      end
      raise ActiveRecord::RecordNotUnique, "no #{locale} text after #{ATTEMPTS} attempts"
    end

    def find_text(card, locale)
      CardText.find_by(card_id: card.id, locale: locale)
    end

    def create_text(card, locale, attributes)
      CardText.transaction(requires_new: true) { CardText.create!(card: card, locale: locale, **attributes) }
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    # The card's card-season in the draft, its scores updated in place; or a
    # new one. A card-season of another season is never touched.
    def upsert_card_season(card, season, scores)
      ATTEMPTS.times do
        card_season = find_card_season(card, season)
        if card_season
          card_season.update!(scores)
          return Success(card_season)
        end

        card_season = create_card_season(card, season, scores)
        return Success(card_season) if card_season
      end
      raise ActiveRecord::RecordNotUnique, "no card-season after #{ATTEMPTS} attempts"
    rescue ActiveRecord::RecordInvalid
      Failure(:invalid_card)
    end

    def find_card_season(card, season)
      CardSeason.find_by(card_id: card.id, season_id: season.id)
    end

    def create_card_season(card, season, scores)
      CardSeason.transaction(requires_new: true) { CardSeason.create!(card: card, season: season, **scores) }
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
