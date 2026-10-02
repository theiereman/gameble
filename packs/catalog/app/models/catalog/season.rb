module Catalog
  # A season of the catalog (AD-5). Imports fill the one draft; publishing
  # it makes its cards drawable and freezes their rarity, dust tier and sets.
  # The published season is the highest-numbered published one.
  class Season < ApplicationRecord
    self.table_name = "catalog_seasons"

    enum :status, { draft: "draft", published: "published" }, default: :draft, validate: true

    has_many :card_seasons, class_name: "Catalog::CardSeason", inverse_of: :season, dependent: nil
    has_many :sets, class_name: "Catalog::Set", inverse_of: :season, dependent: nil

    validates :number, numericality: { only_integer: true, greater_than: 0 }

    # The event stream of a season (AD-10).
    def self.stream_name(id)
      "Catalog::Season$#{id}"
    end

    # The number a new draft takes.
    def self.next_number
      (maximum(:number) || 0) + 1
    end
  end
end
