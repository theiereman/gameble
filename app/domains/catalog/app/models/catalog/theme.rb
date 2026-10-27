module Catalog
  class Theme < ApplicationRecord
    self.table_name = "catalog_themes"

    NAME_LENGTH = 60

    has_secure_token :token, length: 24

    has_many :tag_classifications, class_name: "Catalog::TagClassification", inverse_of: :theme, dependent: nil

    attr_readonly :key

    validates :key, format: { with: Set::KEY_FORMAT }
    validates :name_en, :name_fr, length: { in: 1..NAME_LENGTH }

    def self.stream_name
      "Catalog::Themes"
    end

    def to_param
      token
    end

    def name(locale = I18n.locale)
      locale.to_s == "fr" ? name_fr : name_en
    end
  end
end
