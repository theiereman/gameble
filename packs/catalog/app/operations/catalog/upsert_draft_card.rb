module Catalog
  # Writes a card into the draft season, whatever its source: the card is
  # keyed by an opaque source key the caller builds.
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
  # `prestige_score_version` is an opaque positive Integer naming the formula
  # that gave `prestige_score`; only the caller knows what it means.
  # PublishSeason refuses a draft whose scores come from two formulas.
  #
  # `genres` are theme keys (Catalog::Themes), most-voted first; a genre
  # outside the list is refused. `theme_keys`, the keys of Catalog::Themes
  # (read once by a caller that writes many cards), spares one query per card.
  # `developers` and `franchises` are lists of names, part of the card's identity; `review_count`, the source's number of reviews, is season data
  # like the scores (nil when the source has none to give).
  #
  # Publishes Catalog::DraftCardUpserted on every call, even when nothing
  # changed.
  #
  #   Catalog::UpsertDraftCard.new.call(
  #     source_key: "src:620", release_date: Date.new(2011, 4, 18),
  #     image_url: "https://…", store_url: "https://…",
  #     texts: { "en" => { title: "Portal 2", short_description: "…" }, "fr" => { title: "Portal 2" } },
  #     prestige_score: 0.97, prestige_score_version: 2, rating: 98.0,
  #     publisher: "…", genres: %w[puzzle], tags: %w[puzzle],
  #     developers: %w[Valve], franchises: [ "Portal" ], review_count: 1_000
  #   )
  #   # => Success(card_season) | Failure(:missing_text) | Failure(:invalid_card)
  class UpsertDraftCard < ApplicationOperation
    include CardWriting

    def call(source_key:, release_date:, image_url:, store_url:, texts:, prestige_score:, prestige_score_version:, rating:,
             publisher: nil, genres: [], tags: [], developers: [], franchises: [], review_count: nil, theme_keys: nil)
      card_attributes = step validate_card(source_key:, release_date:, image_url:, store_url:, publisher:, genres:, tags:,
        developers:, franchises:, theme_keys:)
      scores = step validate_scores(prestige_score:, prestige_score_version:, rating:, review_count:)
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
