module Catalog
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
