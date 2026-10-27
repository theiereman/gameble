module Catalog
  class SetTier < ApplicationRecord
    self.table_name = "catalog_set_tiers"

    METALS = %w[bronze silver gold].freeze
    COMPLETE = TierTable::COMPLETE
    TIERS = [ *METALS, *TierTable::RANKS, COMPLETE ].freeze

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
