module Catalog
  class CardSeason < ApplicationRecord
    self.table_name = "catalog_card_seasons"
    SEASON_DATA = %w[prestige_score prestige_score_version rating review_count rarity number main_theme].freeze
    REVIEW_COUNTS = 1..2_147_483_647

    attr_readonly :card_id, :season_id

    belongs_to :card, class_name: "Catalog::Card", inverse_of: :card_seasons
    belongs_to :season, class_name: "Catalog::Season", inverse_of: :card_seasons
    has_many :set_memberships, class_name: "Catalog::SetMembership", inverse_of: :card_season, dependent: nil

    enum :rarity, Rarity::TIERS.invert, prefix: true, validate: { allow_nil: true }

    validates :prestige_score, numericality: true
    validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validates :number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :review_count, numericality: { only_integer: true, in: REVIEW_COUNTS }, allow_nil: true
    validate :season_data_frozen_once_published
    before_destroy :refuse_destroy_once_published

    private

    def season_data_frozen_once_published
      return unless season&.published? && (new_record? || (changed & SEASON_DATA).any?)

      errors.add(:base, :frozen_once_published)
    end

    def refuse_destroy_once_published
      return unless season&.published?

      errors.add(:base, :frozen_once_published)
      throw :abort
    end
  end
end
