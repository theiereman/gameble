module Game
  module Market
    # Where a player stands on each open listing they bid on: leading with their maximum, or outbid with the price to beat.
    module BidStands
      Stand = Data.define(:status, :amount) do
        def leading? = status == :leading
      end

      Found = Data.define(:token, :leader_id, :leader_maximum, :current_price, :starting_price, :settings_id)

      def self.call(player, tokens:)
        return {} if player.nil? || tokens.empty?

        bid_on = Bid.where(player_id: player.id).where.not(outcome: "voided").select(:listing_id)
        found = Listing.open_now.where(token: tokens, id: bid_on).where("seller_id IS DISTINCT FROM ?", player.id).pluck(*Found.members).map { Found.new(*it) }
        basis_points = Settings.where(id: found.map(&:settings_id).uniq).pluck(:id, :increment_basis_points).to_h
        found.to_h { [ it.token, stand(it, player, basis_points.fetch(it.settings_id)) ] }
      end

      def self.stand(listing, player, basis_points)
        return Stand.new(status: :leading, amount: listing.leader_maximum) if listing.leader_id == player.id

        to_beat = AuctionMath.minimum_bid(price: listing.leader_id && listing.current_price, starting_price: listing.starting_price, basis_points:)
        Stand.new(status: :outbid, amount: to_beat)
      end

      private_class_method :stand
    end
  end
end
