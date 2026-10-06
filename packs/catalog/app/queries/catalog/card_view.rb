module Catalog
  # What a card face shows (epic 3, R3; DESIGN.md, Card face), read by
  # CardComponent, the only card renderer.
  #
  # - `id`: the card's slug (AD-15: no database id leaves the server)
  # - `title`: in the locale asked; `publisher`: not localised, may be nil
  # - `year`: the release year; `season_number`: the season's number
  # - `rarity`: the Rarity::TIERS name, as a string ("rare")
  # - `image_url`: the card art's source
  # - `number`: the card's number in its season (R3), nil while unnumbered
  # - `genre`: the `genre` param of the card-season's tome in that season
  #   (a curated genre key, "puzzle"), nil when it is in no tome
  CardView = Data.define(:id, :title, :publisher, :year, :season_number, :rarity, :image_url, :number, :genre) do
    # "S1 · #4 215" (or "#4 215" without the season): the number, its digits
    # grouped by three with a no-break space, no total; nil without a number.
    def number_label(with_season: true)
      return if number.nil?

      label = "##{ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: " ")}"
      with_season ? "S#{season_number} · #{label}" : label
    end
  end
end
