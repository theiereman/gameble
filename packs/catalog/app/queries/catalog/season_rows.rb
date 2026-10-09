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
    Row = Data.define(:id, :card_id, :prestige_score, :prestige_score_version, :rating, :release_date, :publisher, :genres)

    def self.call(season_id)
      CardSeason.where(season_id:).joins(:card).order(:id)
        .pluck(:id, :card_id, :prestige_score, :prestige_score_version, :rating,
          "catalog_cards.release_date", "catalog_cards.publisher", "catalog_cards.genres")
        .map do |id, card_id, prestige_score, prestige_score_version, rating, release_date, publisher, genres|
          Row.new(id:, card_id:, prestige_score:, prestige_score_version:, rating:, release_date:, publisher:, genres:)
        end
    end
  end
end
