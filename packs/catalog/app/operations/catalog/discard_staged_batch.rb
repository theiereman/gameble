module Catalog
  # Deletes a staged batch: the draft season is not touched. Nothing
  # to delete is not a failure.
  #
  # Publishes Catalog::StagedBatchDiscarded on every call.
  #
  #   Catalog::DiscardStagedBatch.new.call(batch_token: run.token)
  #   # => Success(removed), the staged rows deleted
  class DiscardStagedBatch < ApplicationOperation
    def call(batch_token:)
      transaction do
        removed = StagedCardSeason.where(batch_token: batch_token.to_s).delete_all
        step publish(StagedBatchDiscarded.new(data: { batch_token: batch_token.to_s, removed: }),
          stream_name: StagedCardSeason.stream_name(batch_token))
        removed
      end
    end
  end
end
