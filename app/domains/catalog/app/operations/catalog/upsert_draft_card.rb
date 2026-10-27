module Catalog
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

    def create_draft_season
      Season.transaction(requires_new: true) { Season.create!(status: :draft, number: Season.next_number) }
    rescue ActiveRecord::RecordNotUnique
      nil
    end

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
