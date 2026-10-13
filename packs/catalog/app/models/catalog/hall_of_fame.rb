module Catalog
  # The hall of fame sets, in their shelf order, each selecting the
  # card-seasons its rule accepts from their rating (Steam's whole percent)
  # and review count, both frozen at publication. A card-season without a
  # review count is in none; a card can be in several. A set's name is
  # `catalog.hall_of_fame.<key>` in the locales.
  #
  #   Catalog::HallOfFame.keys                       # => ["intouchables", "pepites", "mal-aimes", "phenomenes"]
  #   Catalog::HallOfFame.selects?("pepites", row)   # => true for 98 % and 999 reviews
  module HallOfFame
    RULES = {
      "intouchables" => ->(rating, review_count) { rating >= 97 && review_count >= 20_000 },
      "pepites" => ->(rating, review_count) { rating >= 98 && review_count < 1_000 },
      "mal-aimes" => ->(rating, review_count) { rating.between?(40, 69) && review_count >= 20_000 },
      "phenomenes" => ->(_rating, review_count) { review_count >= 200_000 }
    }.freeze

    def self.keys
      RULES.keys
    end

    def self.selects?(key, row)
      return false if row.review_count.nil?

      RULES.fetch(key).call(row.rating, row.review_count)
    end
  end
end
