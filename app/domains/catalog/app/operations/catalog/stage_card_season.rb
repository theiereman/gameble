module Catalog
  class StageCardSeason < ApplicationOperation
    include CardWriting

    def call(batch_token:, card_id:, prestige_score:, prestige_score_version:, rating:, review_count: nil)
      step require_keys(batch_token, card_id)
      scores = step validate_scores(prestige_score:, prestige_score_version:, rating:, review_count:)

      transaction do
        staged = step write(batch_token, card_id, scores)
        step publish(CardSeasonStaged.new(data: { batch_token:, card_id: }), stream_name: StagedCardSeason.stream_name(batch_token))
        staged
      end
    end

    private

    def require_keys(batch_token, card_id)
      present_string?(batch_token) && card_id.is_a?(Integer) ? Success() : Failure(:invalid_card)
    end

    def write(batch_token, card_id, scores)
      staged = StagedCardSeason.find_or_initialize_by(batch_token:, card_id:)
      staged.update!(scores)
      Success(staged)
    rescue ActiveRecord::RecordInvalid
      Failure(:invalid_card)
    end
  end
end
