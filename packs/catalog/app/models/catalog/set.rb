module Catalog
  # A set of a season: the games of a theme, of a franchise or of a studio,
  # the games a hall of fame rule selects from their reviews, or the UFOs,
  # the games of no theme. Seasons published before themes hold the retired
  # kinds: a publisher's games, a volume of a genre's tome, or the best rated
  # of a release year. Its key is URL-safe and unique within its season and
  # kind; `params` holds what a screen needs to name it (theme, franchise,
  # studio, hall_of_fame; publisher, genre and volume, year). Built when the
  # season is published (SetBuilder), with its tiers, and never changed
  # afterwards.
  class Set < ApplicationRecord
    self.table_name = "catalog_sets"

    # A set never moves to another season, so its freeze cannot be dodged.
    attr_readonly :season_id

    # What `parameterize` produces: lowercase letters, digits, underscores and
    # single dashes.
    KEY_FORMAT = /\A[a-z0-9_]+(?:-[a-z0-9_]+)*\z/

    enum :kind, {
      theme: "theme", franchise: "franchise", studio: "studio", hall_of_fame: "hall_of_fame", ufo: "ufo",
      publisher: "publisher", tome: "tome", best_of_year: "best_of_year"
    }, validate: true

    # The kinds some publication has built, today's then the retired ones.
    BUILT_KINDS = %w[theme franchise studio hall_of_fame ufo tome publisher best_of_year].freeze

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
