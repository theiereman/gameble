module Catalog
  # How many distinct cards of a set a player needs for one of its tiers:
  # bronze, silver and gold (a theme's), or complete (every set's). Written
  # when the season is published and never changed afterwards.
  class SetTier < ApplicationRecord
    self.table_name = "catalog_set_tiers"

    TIERS = %w[bronze silver gold complete].freeze

    # A tier never moves to another set.
    attr_readonly :set_id

    belongs_to :set, class_name: "Catalog::Set", inverse_of: :tiers

    validates :tier, inclusion: { in: TIERS }
    validates :required, numericality: { only_integer: true, greater_than: 0 }
    validate :frozen_once_published
    before_destroy :refuse_destroy_once_published

    private

    def frozen_once_published
      return unless set&.season&.published? && (new_record? || changed?)

      errors.add(:base, :frozen_once_published)
    end

    def refuse_destroy_once_published
      return unless set&.season&.published?

      errors.add(:base, :frozen_once_published)
      throw :abort
    end
  end
end
