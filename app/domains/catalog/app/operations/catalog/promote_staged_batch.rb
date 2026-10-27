module Catalog
  class PromoteStagedBatch < ApplicationOperation
    def call(batch_token:, season_number:)
      transaction do
        staged = StagedCardSeason.where(batch_token: batch_token.to_s)
        step require_rows(staged)
        season = step lock_draft(season_number)
        removed = CardSeason.where(season_id: season.id).delete_all
        promoted = step copy(batch_token.to_s, season)
        staged.delete_all
        step publish(StagedBatchPromoted.new(data: { batch_token: batch_token.to_s, season_id: season.id, promoted:, removed: }),
          stream_name: StagedCardSeason.stream_name(batch_token))
        season
      end
    end

    private

    def require_rows(staged)
      staged.exists? ? Success() : Failure(:empty_batch)
    end

    def lock_draft(season_number)
      season = Season.draft.lock("FOR UPDATE").take
      return Success(season) if season&.number == season_number
      return Failure(:stale_batch) if season || Season.next_number != season_number

      Success(Season.create!(status: :draft, number: season_number))
    rescue ActiveRecord::RecordNotUnique
      Failure(:stale_batch)
    end

    def copy(batch_token, season)
      sql = CardSeason.sanitize_sql_array([ <<~SQL.squish, season.id, batch_token ])
        INSERT INTO catalog_card_seasons
          (card_id, season_id, prestige_score, prestige_score_version, rating, review_count, created_at, updated_at)
        SELECT card_id, ?, prestige_score, prestige_score_version, rating, review_count, now(), now()
        FROM catalog_staged_card_seasons WHERE batch_token = ? ORDER BY id
      SQL
      Success(CardSeason.connection.exec_update(sql))
    end
  end
end
