module Catalog
  # A card's season scores staged by an import run, beside the draft season,
  # until the batch is promoted into the draft or discarded. Rows of
  # one batch share a token the run passes in; a card has one row per batch.
  #
  # Written only through the operations of this pack.
  class StagedCardSeason < ApplicationRecord
    self.table_name = "catalog_staged_card_seasons"

    belongs_to :card, class_name: "Catalog::Card", inverse_of: false

    # The event stream of a batch.
    def self.stream_name(batch_token)
      "Catalog::StagedBatch$#{batch_token}"
    end
  end
end
