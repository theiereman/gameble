module Catalog
  class SetMembership < ApplicationRecord
    self.table_name = "catalog_set_memberships"

    attr_readonly :set_id, :card_season_id

    belongs_to :set, class_name: "Catalog::Set", inverse_of: :memberships
    belongs_to :card_season, class_name: "Catalog::CardSeason", inverse_of: :set_memberships

    validates :position, numericality: { only_integer: true, greater_than: 0 }
    validate :same_season
    validate :frozen_once_published
    before_destroy :refuse_destroy_once_published

    private

    def same_season
      return if set.nil? || card_season.nil? || set.season_id == card_season.season_id

      errors.add(:card_season, :other_season)
    end

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
