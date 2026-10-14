module Catalog
  # A card (CAP-2): one game of the catalog, whatever source it came from.
  # Its fields and texts are its identity, updated in place by every import,
  # published seasons included; what belongs to a season lives on its
  # Catalog::CardSeason. Among them, `developers` and `franchises` are the
  # source's names, in its order, empty when it names none.
  #
  # Keyed by an opaque source key built by the writer (AD-4). Addressed in
  # URLs by a slug, set once from the English title and never changed, so
  # card links stay stable (AD-15).
  #
  # Written only through the operations of this pack (AD-3).
  class Card < ApplicationRecord
    self.table_name = "catalog_cards"

    # The slug's btree index rejects values above about 2.7 kB.
    SLUG_TITLE_LIMIT = 100

    extend FriendlyId
    friendly_id :slug_candidates, use: :slugged

    attr_readonly :slug

    has_many :texts, class_name: "Catalog::CardText", inverse_of: :card, dependent: nil
    has_many :card_seasons, class_name: "Catalog::CardSeason", inverse_of: :card, dependent: nil

    validates :source_key, :release_date, :image_url, :store_url, presence: true

    # The card's text in a locale, or nil.
    def text(locale)
      texts.detect { |text| text.locale == locale.to_s }
    end

    private

    # The English title, then the title and the release year, then a random
    # suffix. A title that leaves nothing once parameterized (a non-Latin
    # title) goes straight to the year and a random suffix.
    def slug_candidates
      title = truncated_title(text("en")&.title.to_s)
      year = release_date&.year
      suffix = -> { SecureRandom.alphanumeric(6).downcase }

      if title.blank?
        [ [ year, suffix ] ]
      else
        [ title, [ title, year ], [ title, year, suffix ] ]
      end
    end

    def truncated_title(title)
      slug = normalize_friendly_id(title)
      return slug if slug.length <= SLUG_TITLE_LIMIT

      head = slug[0, SLUG_TITLE_LIMIT]
      word = head.sub(/-[^-]*\z/, "")
      word.empty? ? head : word
    end
  end
end
