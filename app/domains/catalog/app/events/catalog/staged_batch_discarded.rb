module Catalog
  # Published when a staged batch is deleted without touching the draft
  # (Catalog::DiscardStagedBatch), even when it held no row.
  # data = { batch_token:, removed: }, on the batch's stream.
  class StagedBatchDiscarded < RubyEventStore::Event
  end
end
