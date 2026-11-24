module Game
  module Market
    # The rarities a copy can be sold to an order in one press; above them an order only backs an auction.
    module DirectSale
      RARITIES = %w[common uncommon].freeze

      def self.rarity?(rarity) = RARITIES.include?(rarity.to_s)

      def self.edition?(card_season_id) = rarity?(Catalog::CardSeason.where(id: card_season_id).pick(:rarity))

      def self.edition_ids(card_season_ids) = Catalog::CardSeason.where(id: card_season_ids, rarity: RARITIES).pluck(:id)
    end
  end
end
