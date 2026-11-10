module Game
  module Market
    module RemovedPresence
      def self.sellers
        Listing.open_now.joins(:seller).merge(Accounts::Player.removed).pluck(:id, :seller_id)
      end

      def self.leaders(now: Time.current)
        Listing.open_now.where(ends_at: now..).where.not(leader_id: nil).joins(:leader).merge(Accounts::Player.removed).pluck(:id, :seller_id)
      end
    end
  end
end
