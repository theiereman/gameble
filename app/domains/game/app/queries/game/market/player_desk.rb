module Game
  module Market
    # Where a player stands on the market: their PiCoins, their bids and their sales.
    module PlayerDesk
      Desk = Data.define(:balance, :outbid, :leading, :selling, :selling_with_offers)

      def self.call(player)
        open = Listing.open_now
        sales = open.where(seller_id: player.id)
        Desk.new(balance: Balance.call(player), outbid: OutbidCount.call(player), leading: open.where(leader_id: player.id).count,
          selling: sales.count, selling_with_offers: sales.where.not(leader_id: nil).count)
      end
    end
  end
end
