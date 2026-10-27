module Catalog
  # Published when a staged batch replaces the draft season's card-seasons
  # (Catalog::PromoteStagedBatch). Identifiers and counts only:
  # data = { batch_token:, season_id:, promoted:, removed: }, on the batch's stream.
  class StagedBatchPromoted < RubyEventStore::Event
  end
end
