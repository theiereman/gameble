module Catalog
  # A card in a season (AD-5): the source's scores for that season, and the
  # rarity and number in the season (R3) its publication gives. Scores follow
  # the source while the season is a draft; rarity and number stay NULL until
  # it is published (a season published before numbers existed stays
  # unnumbered until `catalog:number_seasons`). Once published, none of them
  # changes again, and no card-season is added to or removed from the season.
  # A card-season never moves to another card or season.
  #
  # `prestige_score` is opaque here and only ordered;
  # `prestige_score_version` names, as opaquely, the formula that gave it
  # (nil before versions existed); `rating` is the source's review score in
  # percent; `review_count` its number of reviews (nil when the source gave
  # none). Catalog::FillCardSources fills, once, a review count left NULL by
  # an import that did not carry it, published seasons included.
  class CardSeason < ApplicationRecord
    self.table_name = "catalog_card_seasons"
    # Dropped by RemoveDustTierFromCatalogCardSeasons (AD-28's contract step).
    # Kept until every environment has run that migration, so a process
    # booted before it never reads or writes the column.
    self.ignored_columns = %w[dust_tier]

    # The columns frozen once the season is published.
    SEASON_DATA = %w[prestige_score prestige_score_version rating review_count rarity number].freeze
    # The column is an integer.
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
