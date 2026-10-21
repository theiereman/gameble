module Catalog
  # What the operations that write cards share: the validation of a
  # card's attributes, texts and season scores, and the upsert of the card
  # and its texts by source key, in place. Included by UpsertDraftCard,
  # UpsertCardIdentity and StageCardSeason.
  module CardWriting
    # Tries at an insert that meets a unique index before giving up.
    ATTEMPTS = 3
    # The column is a smallint.
    SCORE_VERSIONS = 1..32_767

    private

    def validate_card(source_key:, release_date:, image_url:, store_url:, publisher:, genres:, tags:, developers:, franchises:)
      valid = [ source_key, image_url, store_url ].all? { |value| present_string?(value) } &&
        release_date.is_a?(Date) &&
        (publisher.nil? || publisher.is_a?(String)) &&
        [ genres, tags, developers, franchises ].all? { |list| list.is_a?(Array) && list.all? { |item| present_string?(item) } } &&
        genres.all? { |genre| Themes.key?(genre) }
      return Failure(:invalid_card) unless valid

      Success(source_key:, release_date:, image_url:, store_url:, publisher: publisher.presence, genres:, tags:, developers:, franchises:)
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

    # Scores and counts are numbers as given, never parsed from strings.
    def validate_scores(prestige_score:, prestige_score_version:, rating:, review_count:)
      if real?(prestige_score) && score_version?(prestige_score_version) && real?(rating) && rating.between?(0, 100) &&
          (review_count.nil? || review_count?(review_count))
        Success(prestige_score:, prestige_score_version:, rating:, review_count:)
      else
        Failure(:invalid_card)
      end
    end

    def real?(value)
      value.is_a?(Numeric) && value.real? && value.finite?
    end

    def score_version?(value)
      value.is_a?(Integer) && SCORE_VERSIONS.cover?(value)
    end

    def review_count?(value)
      value.is_a?(Integer) && CardSeason::REVIEW_COUNTS.cover?(value)
    end
  end
end
