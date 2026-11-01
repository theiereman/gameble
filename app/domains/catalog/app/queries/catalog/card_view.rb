module Catalog
  CardView = Data.define(:id, :title, :publisher, :year, :season_number, :rarity, :image_url, :number, :genre, :card_id) do
    def initialize(card_id: nil, **) = super

    def number_label(with_season: true)
      label = "##{ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: " ")}"
      with_season ? "S#{season_number} · #{label}" : label
    end
  end
end
