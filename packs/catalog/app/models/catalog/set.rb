module Catalog
  # A set of a season (CAP-6): a publisher's games, a volume of a genre's
  # tome, or the best rated of a release year. Its key is URL-safe and unique
  # within its season and kind; `params` holds what a screen needs to name it
  # (publisher, genre and volume, year). Built when the season is published
  # (SetBuilder) and never changed afterwards (AD-5).
  class Set < ApplicationRecord
    self.table_name = "catalog_sets"

    # A set never moves to another season, so its freeze cannot be dodged.
    attr_readonly :season_id

    # What `parameterize` produces: lowercase letters, digits, underscores and
    # single dashes.
    KEY_FORMAT = /\A[a-z0-9_]+(?:-[a-z0-9_]+)*\z/

    enum :kind, { publisher: "publisher", tome: "tome", best_of_year: "best_of_year" }, validate: true

    belongs_to :season, class_name: "Catalog::Season", inverse_of: :sets
    has_many :memberships, class_name: "Catalog::SetMembership", inverse_of: :set, dependent: nil

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
