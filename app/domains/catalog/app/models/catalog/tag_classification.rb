module Catalog
  class TagClassification < ApplicationRecord
    self.table_name = "catalog_tag_classifications"

    belongs_to :theme, class_name: "Catalog::Theme", optional: true, inverse_of: :tag_classifications

    validates :tag_key, format: { with: TagKey::FORMAT }
    validate :theme_or_dismissed

    private

    def theme_or_dismissed
      errors.add(:base, :invalid) if theme_id.nil? == !not_a_theme
    end
  end
end
