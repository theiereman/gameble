module Game
  module Market
    module DeletionNote
      Note = Data.define(:balance)

      def self.call(player:)
        wallet = Wallet.find_by(player_id: player.id)
        balance = wallet ? wallet.available + wallet.committed : 0
        Note.new(balance:) if balance.positive? || open_listing?(player)
      end

      def self.open_listing?(player)
        Listing.open_now.where(seller_id: player.id).or(Listing.open_now.where(leader_id: player.id)).exists?
      end

      private_class_method :open_listing?
    end
  end
end
