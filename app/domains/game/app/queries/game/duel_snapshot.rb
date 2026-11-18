module Game
  module DuelSnapshot
    def self.call(deck) = for_cards(DeckCard.where(deck_id: deck.id).pluck(:card_season_id))

    def self.for_cards(card_season_ids)
      rows = Catalog::CardSeason.where(id: card_season_ids).joins(:season).order("catalog_seasons.number", "catalog_card_seasons.number")
        .pluck("catalog_card_seasons.id", "catalog_card_seasons.card_id", "catalog_card_seasons.number", Arel.sql("catalog_card_seasons.rarity AS tier"))
      profiles = DuelProfiles.call(rows.map(&:first))
      rows.map do |card_season_id, card_id, number, rarity|
        stats = profiles.fetch(card_season_id).stats.to_h do |stat|
          [ stat.name, DuelCard::Stat.new(value: stat.value, percentile: stat.percentile, median_distance: stat.median_distance) ]
        end
        DuelCard.new(card_season_id:, card_id:, number:, rarity:, stats:)
      end
    end
  end
end
