module Catalog
  # A set of a season (CAP-6): a publisher's games, a volume of a genre's
  # tome, or the best rated of a release year. Its key is URL-safe and unique
  # within its season and kind. Built when the season is published.
  class Set < ApplicationRecord
    self.table_name = "catalog_sets"

    # What `parameterize` produces: lowercase letters, digits, underscores and
    # single dashes.
    KEY_FORMAT = /\A[a-z0-9_]+(?:-[a-z0-9_]+)*\z/

    enum :kind, { publisher: "publisher", tome: "tome", best_of_year: "best_of_year" }, validate: true

    belongs_to :season, class_name: "Catalog::Season", inverse_of: :sets
    has_many :memberships, class_name: "Catalog::SetMembership", inverse_of: :set, dependent: nil

    validates :key, format: { with: KEY_FORMAT }
  end
end
