module Catalog
  # A card in a season (AD-5): the source's scores for that season, and the
  # rarity and dust tier its publication gives. Scores follow the source
  # while the season is a draft; rarity and dust tier stay NULL until it is
  # published. Once published, none of them changes again, and no card-season
  # is added to or removed from the season. A card-season never moves to
  # another card or season.
  #
  # `prestige_score` is opaque here and only ordered; `rating` is the
  # source's review score in percent.
  class CardSeason < ApplicationRecord
    self.table_name = "catalog_card_seasons"

    # The columns frozen once the season is published.
    SEASON_DATA = %w[prestige_score rating rarity dust_tier].freeze

    attr_readonly :card_id, :season_id

    belongs_to :card, class_name: "Catalog::Card", inverse_of: :card_seasons
    belongs_to :season, class_name: "Catalog::Season", inverse_of: :card_seasons
    has_many :set_memberships, class_name: "Catalog::SetMembership", inverse_of: :card_season, dependent: nil

    enum :rarity, Rarity::TIERS.invert, prefix: true, validate: { allow_nil: true }
    enum :dust_tier, Dust::LEVELS.invert, prefix: :dust, validate: { allow_nil: true }

    validates :prestige_score, numericality: true
    validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
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
