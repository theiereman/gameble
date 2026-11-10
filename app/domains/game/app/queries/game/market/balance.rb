module Game
  module Market
    # What a player holds in PiCoins: free to spend and committed to auctions, zero and zero before any wallet row.
    module Balance
      Figures = Data.define(:available, :committed)

      def self.call(player)
        Figures.new(*(Wallet.where(player_id: player.id).pick(:available, :committed) || [ 0, 0 ]))
      end
    end
  end
end
