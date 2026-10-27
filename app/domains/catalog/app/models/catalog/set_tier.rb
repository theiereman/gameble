module Catalog
  # How many distinct cards of a set a player needs for one of its tiers:
  # a rank of TierTable (novice to master), bronze, silver or gold (the
  # metals of seasons published before the ranks), or complete (every
  # set's). Written when the season is published and never changed
  # afterwards.
  class SetTier < ApplicationRecord
    self.table_name = "catalog_set_tiers"

    METALS = %w[bronze silver gold].freeze
    COMPLETE = TierTable::COMPLETE
    # Every tier name, the lower first. Tiers are ordered by `required`; this
    # order only breaks a tie between two tiers of one set asking the same
    # count, which a metal set of a few cards can hold.
    TIERS = [ *METALS, *TierTable::RANKS, COMPLETE ].freeze

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
