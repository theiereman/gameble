module Catalog
  class CardText < ApplicationRecord
    self.table_name = "catalog_card_texts"

    LOCALES = %w[en fr].freeze

    belongs_to :card, class_name: "Catalog::Card", inverse_of: :texts

    validates :locale, inclusion: { in: LOCALES }
    validates :title, presence: true
  end
end
