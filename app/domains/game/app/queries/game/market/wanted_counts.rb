module Game
  module Market
    # How many players want each game at each rarity, a goal counting at every rarity and an order at those it reaches.
    module WantedCounts
      TIERS_JOIN = "CROSS JOIN unnest(ARRAY[#{Catalog::Rarity::TIERS.keys.join(", ")}]) AS tiers(tier)".freeze

      def self.call(card_ids, except: nil)
        counts = Hash.new(0)
        return counts if card_ids.empty?

        Wanted.in_play.where(card_id: card_ids).where.not(player_id: except).joins(TIERS_JOIN)
          .where("game_market_wanted.reason = 'goal' OR tiers.tier = ANY(game_market_wanted.rarities)")
          .group(:card_id, "tiers.tier").distinct.count(:player_id)
          .each { |(card_id, tier), players| counts[[ card_id, Catalog::Rarity::TIERS.fetch(tier).to_s ]] = players }
        counts
      end
    end
  end
end
