module Catalog
  # A card's title and short description in one locale (AD-18). The short
  # description is plain text: the writer strips any markup.
  class CardText < ApplicationRecord
    self.table_name = "catalog_card_texts"

    LOCALES = %w[en fr].freeze

    belongs_to :card, class_name: "Catalog::Card", inverse_of: :texts

    validates :locale, inclusion: { in: LOCALES }
    validates :title, presence: true
  end
end
