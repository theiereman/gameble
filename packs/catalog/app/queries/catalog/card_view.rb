module Catalog
  # What a card shows, face and back (epic 3, R6, R7; DESIGN.md, Card face,
  # Card back): read by CardComponent and, through `to_props`, by the React
  # Card, whose TypeScript CardView type mirrors it in camelCase.
  #
  # - `id`: the card's slug (AD-15: no database id leaves the server)
  # - `title`: in the locale asked; `publisher`: not localised, may be nil
  # - `year`: the release year; `season_number`: the season's number
  # - `rarity`: the Rarity::TIERS name, as a string ("rare")
  # - `dust`: the Dust::LEVELS level, 0 to 4
  # - `image_url`: the card art's source
  # - `number`: the card's number in its season (R3), nil while unnumbered
  # - `genre`: the `genre` param of the card-season's tome in that season
  #   (a curated genre key, "puzzle"), nil when it is in no tome
  CardView = Data.define(:id, :title, :publisher, :year, :season_number, :rarity, :dust, :image_url, :number, :genre) do
    # "S1 · #4 215": the season and the number, its digits grouped by three
    # with a no-break space, no total; nil without a number.
    def number_label
      return if number.nil?

      "S#{season_number} · ##{ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: " ")}"
    end

    def to_props
      { id:, title:, publisher:, year:, seasonNumber: season_number, rarity:, dust:, imageUrl: image_url, number:, genre: }
    end
  end
end
