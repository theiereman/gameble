module Catalog
  # What a card shows, face and back (epic 3, R6, R7; DESIGN.md, Card face,
  # Card back): read by CardComponent and, through `to_props`, by the React
  # Card, whose TypeScript CardView type mirrors it in camelCase.
  #
  # - `id`: the card's slug (AD-15: no database id leaves the server)
  # - `title`: in the locale asked; `publisher`: not localised, may be nil
  # - `year`: the release year; `season_number`: the season's number
  # - `rarity`: the Rarity::TIERS name, as a string ("sapphire")
  # - `dust`: the Dust::LEVELS level, 0 to 4
  # - `image_url`: the card art's source
  CardView = Data.define(:id, :title, :publisher, :year, :season_number, :rarity, :dust, :image_url) do
    def to_props
      { id:, title:, publisher:, year:, seasonNumber: season_number, rarity:, dust:, imageUrl: image_url }
    end
  end
end
