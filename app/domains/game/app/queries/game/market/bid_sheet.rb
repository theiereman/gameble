module Game
  module Market
    # What a player's bidding form is drawn from: the minimum, the lead and the available figure. Only the leader's own maximum is read, for the leader.
    module BidSheet
      Sheet = Data.define(:minimum, :leading, :own_maximum, :available, :current_price, :buy_now_price, :soft_close_minutes)

      SECONDS_PER_MINUTE = 60

      def self.call(token:, player:)
        return unless player

        listing = Listing.where(token: token.to_s, status: "open").where("ends_at > ?", Time.current)
          .select(:id, :seller_id, :leader_id, :current_price, :starting_price, :buy_now_price, :settings_id).first
        return unless listing && listing.seller_id != player.id && !player.removed?

        settings = Settings.find(listing.settings_id)
        leader = present_leader(listing)
        own_maximum = Listing.where(id: listing.id).pick(:leader_maximum) if leader == player.id
        Sheet.new(minimum: minimum(listing, settings, leader, own_maximum), leading: !own_maximum.nil?, own_maximum:,
          available: Balance.call(player).available, current_price: listing.current_price, buy_now_price: listing.buy_now_price,
          soft_close_minutes: settings.soft_close_seconds / SECONDS_PER_MINUTE)
      end

      def self.present_leader(listing)
        listing.leader_id unless listing.leader_id.nil? || Accounts::Player.find(listing.leader_id).removed?
      end

      def self.minimum(listing, settings, leader, own_maximum)
        return AuctionMath.raise_minimum(own_maximum) if own_maximum

        AuctionMath.minimum_bid(price: leader && listing.current_price, starting_price: listing.starting_price, buy_now_price: listing.buy_now_price,
          basis_points: settings.increment_basis_points)
      end

      private_class_method :present_leader, :minimum
    end
  end
end
