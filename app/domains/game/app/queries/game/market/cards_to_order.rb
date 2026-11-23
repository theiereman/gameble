module Game
  module Market
    # Per goal, the cards it misses that the player has no open order on, in set order, as card views:
    # nothing for a visitor or while the market is not open.
    module CardsToOrder
      def self.call(player, needs, locale:)
        return {} if player.nil? || needs.all? { it.missing_card_ids.empty? } || !MarketState.call.open?

        ordered = Order.where(player_id: player.id, status: "open").pluck(:card_id).to_set
        missing = needs.to_h { |need| [ need.goal_id, need.missing_card_ids.reject { ordered.include?(it) } ] }
        faces = Catalog::LatestPublishedCardSeasons.call(missing.values.flatten)
        views = Catalog::CardViews.call(faces.values, locale:)
        missing.transform_values { |card_ids| card_ids.filter_map { views[faces[it]] } }
      end
    end
  end
end
