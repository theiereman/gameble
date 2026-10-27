module Catalog
  class StagedCardSeason < ApplicationRecord
    self.table_name = "catalog_staged_card_seasons"

    belongs_to :card, class_name: "Catalog::Card", inverse_of: false

    def self.stream_name(batch_token)
      "Catalog::StagedBatch$#{batch_token}"
    end
  end
end
