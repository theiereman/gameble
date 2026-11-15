module Catalog
  class Season < ApplicationRecord
    self.table_name = "catalog_seasons"

    NAME_LENGTH = 60

    enum :status, { draft: "draft", published: "published" }, default: :draft, validate: true

    has_many :card_seasons, class_name: "Catalog::CardSeason", inverse_of: :season, dependent: nil
    has_many :sets, class_name: "Catalog::Set", inverse_of: :season, dependent: nil

    validates :number, numericality: { only_integer: true, greater_than: 0 }
    validates :name_en, :name_fr, length: { in: 1..NAME_LENGTH }, allow_nil: true

    def self.stream_name(id)
      "Catalog::Season$#{id}"
    end

    def self.next_number
      (maximum(:number) || 0) + 1
    end

    def name(locale)
      locale.to_s == "fr" ? name_fr : name_en
    end
  end
end
