module Game
  module Handlers
    module TradeAccepted
      def self.call(event)
        trade_id, proposer_id, recipient_id = event.data.values_at(:trade_id, :proposer_id, :recipient_id)
        sides = TradeItem.where(trade_id:).pluck(:side, :card_season_id)
        given = ->(side) { sides.filter_map { |item_side, card_season_id| card_season_id if item_side == side } }
        at = event.metadata[:timestamp] || Time.current
        new_entry = FeedEntry.record_trade(trade_id:, proposer_id:, recipient_id:, offer: given.("offer"), request: given.("request"),
          rarities: rarities(sides.map(&:last)), at:)
        WeeklyContribution.record_trade(proposer_id, recipient_id, at) if new_entry
      end

      def self.rarities(card_season_ids)
        Catalog::CardSeason.where(id: card_season_ids.uniq).where.not(rarity: nil).pluck(:id, :rarity)
          .to_h { |id, name| [ id, Catalog::Rarity::TIERS.key(name.to_sym) ] }
      end
      private_class_method :rarities
    end
  end
end
