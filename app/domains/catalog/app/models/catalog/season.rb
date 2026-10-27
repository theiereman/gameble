module Catalog
  class Season < ApplicationRecord
    self.table_name = "catalog_seasons"

    enum :status, { draft: "draft", published: "published" }, default: :draft, validate: true

    has_many :card_seasons, class_name: "Catalog::CardSeason", inverse_of: :season, dependent: nil
    has_many :sets, class_name: "Catalog::Set", inverse_of: :season, dependent: nil

    validates :number, numericality: { only_integer: true, greater_than: 0 }

    def self.stream_name(id)
      "Catalog::Season$#{id}"
    end

    def self.next_number
      (maximum(:number) || 0) + 1
    end
  end
end
