module Catalog
  # The card-seasons of a season with what the cut and the sets read from
  # them and their cards, in one pluck (AD-5). Takes no lock of its own:
  # PublishSeason calls it inside its transaction, the calibration preview
  # outside one. `season_id` is an id, or a relation selecting one
  # (the preview passes the draft's, so the season is read in the same
  # query).
  #
  #   Catalog::SeasonRows.call(season.id) # => [Catalog::SeasonRows::Row, …]
  module SeasonRows
    # `rating` is the source's review score in percent; `genres` the card's
    # genres, the first one first; `prestige_score_version` the formula that
    # gave the score, nil for a card-season scored before versions existed.
    # `title` is the card's English title, nil without one; `developers` and
    # `franchises` the card's names, in the source's order; `review_count`
    # the source's number of reviews, nil when it gave none.
    Row = Data.define(:id, :card_id, :prestige_score, :prestige_score_version, :rating, :release_date, :genres,
      :title, :developers, :franchises, :publisher, :review_count)

    ENGLISH_TEXT = <<~SQL.squish.freeze
      LEFT JOIN catalog_card_texts ON catalog_card_texts.card_id = catalog_cards.id AND catalog_card_texts.locale = 'en'
    SQL

    COLUMNS = [
      :id, :card_id, :prestige_score, :prestige_score_version, :rating,
      "catalog_cards.release_date", "catalog_cards.genres", "catalog_card_texts.title", "catalog_cards.developers",
      "catalog_cards.franchises", "catalog_cards.publisher", :review_count
    ].freeze

    def self.call(season_id)
      CardSeason.where(season_id:).joins(:card).joins(ENGLISH_TEXT).order(:id).pluck(*COLUMNS)
        .map do |id, card_id, prestige_score, prestige_score_version, rating, release_date, genres, title, developers, franchises, publisher, review_count|
          Row.new(id:, card_id:, prestige_score:, prestige_score_version:, rating:, release_date:, genres:,
            title:, developers:, franchises:, publisher:, review_count:)
        end
    end
  end
end
