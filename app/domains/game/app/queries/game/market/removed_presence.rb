module Game
  module Market
    module RemovedPresence
      def self.sellers
        Listing.open_now.joins(:seller).merge(Accounts::Player.removed).pluck(:id, :seller_id)
      end

      def self.wallets
        Wallet.where("available > 0 AND committed = 0").where(player_id: Accounts::Player.where.not(deleted_at: nil).select(:id))
          .where.not(player_id: Listing.open_now.select(:seller_id)).where.not(player_id: Listing.open_now.where.not(leader_id: nil).select(:leader_id)).pluck(:player_id)
      end

      def self.leaders(now: Time.current)
        Listing.open_now.where(ends_at: now..).where.not(leader_id: nil).joins(:leader).merge(Accounts::Player.removed).pluck(:id, :seller_id)
      end
    end
  end
end
