module Game
  module DuelSnapshot
    def self.call(deck)
      rows = DeckCard.where(deck_id: deck.id)
        .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_deck_cards.card_season_id")
        .joins("JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id")
        .order("catalog_seasons.number", "catalog_card_seasons.number")
        .pluck("game_deck_cards.card_season_id", "game_deck_cards.card_id", "catalog_card_seasons.number", "catalog_card_seasons.rarity")
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
