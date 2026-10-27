module Catalog
  class Card < ApplicationRecord
    self.table_name = "catalog_cards"

    SLUG_TITLE_LIMIT = 100

    extend FriendlyId
    friendly_id :slug_candidates, use: :slugged

    attr_readonly :slug

    has_many :texts, class_name: "Catalog::CardText", inverse_of: :card, dependent: nil
    has_many :card_seasons, class_name: "Catalog::CardSeason", inverse_of: :card, dependent: nil

    validates :source_key, :release_date, :image_url, :store_url, presence: true

    def text(locale)
      texts.detect { |text| text.locale == locale.to_s }
    end

    private

    def slug_candidates
      title = slug_base(text("en")&.title.to_s)
      year = release_date&.year
      suffix = -> { SecureRandom.alphanumeric(6).downcase }

      if title.blank?
        [ [ year, suffix ] ]
      else
        [ title, [ title, year ], [ title, year, suffix ] ]
      end
    end

    def slug_base(title)
      slug = normalize_friendly_id(title)
      return slug if slug.length <= SLUG_TITLE_LIMIT

      head = slug[0, SLUG_TITLE_LIMIT]
      return head if slug[SLUG_TITLE_LIMIT] == "-"

      whole_words = head.sub(/-[^-]*\z/, "")
      whole_words.empty? ? head : whole_words
    end
  end
end
