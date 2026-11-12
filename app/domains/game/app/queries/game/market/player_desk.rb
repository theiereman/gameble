module Game
  module Market
    # Where a player stands on the market: their PiCoins, their bids, their sales and the spare copies they could entrust.
    module PlayerDesk
      Desk = Data.define(:balance, :outbid, :leading, :selling, :selling_with_offers, :spare_copies) do
        def newcomer? = balance.available.zero? && balance.committed.zero? && selling.zero? && leading.zero? && outbid.zero?
      end

      def self.call(player)
        open = Listing.open_now
        sales = open.where(seller_id: player.id)
        Desk.new(balance: Balance.call(player), outbid: OutbidCount.call(player), leading: open.where(leader_id: player.id).count,
          selling: sales.count, selling_with_offers: sales.where.not(leader_id: nil).count, spare_copies: spare_copies(player))
      end

      def self.spare_copies(player)
        Holding.where(player_id: player.id, card_season_id: Catalog::CardSeason.where.not(rarity: nil).select(:id))
          .where("quantity > GREATEST(reserved, 1)").sum(Arel.sql("quantity - GREATEST(reserved, 1)"))
      end

      private_class_method :spare_copies
    end
  end
end
