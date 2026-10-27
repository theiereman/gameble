module Catalog
  # What the administrators decided about one Steam tag, by its key
  # (TagKey): attached to a theme, or not a theme. A tag without a
  # classification is unclassified, and blocks the publication when a draft
  # card carries it among its most-voted tags.
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
