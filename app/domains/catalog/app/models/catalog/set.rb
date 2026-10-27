module Catalog
  class Set < ApplicationRecord
    self.table_name = "catalog_sets"

    attr_readonly :season_id

    KEY_FORMAT = /\A[a-z0-9_]+(?:-[a-z0-9_]+)*\z/

    enum :kind, SetKind::ALL.index_by(&:to_sym), validate: true

    belongs_to :season, class_name: "Catalog::Season", inverse_of: :sets
    has_many :memberships, class_name: "Catalog::SetMembership", inverse_of: :set, dependent: nil
    has_many :tiers, class_name: "Catalog::SetTier", inverse_of: :set, dependent: nil

    validates :key, format: { with: KEY_FORMAT }
    validate :frozen_once_published
    before_destroy :refuse_destroy_once_published

    private

    def frozen_once_published
      return unless season&.published? && (new_record? || changed?)

      errors.add(:base, :frozen_once_published)
    end

    def refuse_destroy_once_published
      return unless season&.published?

      errors.add(:base, :frozen_once_published)
      throw :abort
    end
  end
end
