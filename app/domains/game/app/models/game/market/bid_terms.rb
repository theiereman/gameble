module Game
  module Market
    class BidTerms < Data.define(:listing, :player, :maximum, :settings, :now, :leader, :displaced)
      Lead = Data.define(:player_id, :maximum)

      def self.lead_of(player_id, maximum) = player_id && Lead.new(player_id:, maximum:)

      def basis_points = settings.increment_basis_points

      def buy_now? = !listing.buy_now_price.nil? && maximum >= listing.buy_now_price

      def own_lead? = leader&.player_id == player.id

      def held = own_lead? ? leader.maximum : 0

      def needed = (buy_now? ? listing.buy_now_price : maximum) - held

      def minimum
        return AuctionMath.raise_minimum(leader.maximum) if own_lead?

        AuctionMath.minimum_bid(price: leader && listing.current_price, starting_price: listing.starting_price, buy_now_price: listing.buy_now_price, basis_points:)
      end

      def branch
        if buy_now? then :buy_now
        elsif own_lead? then :raise
        elsif leader.nil? || maximum > leader.maximum then :new_leader
        else :beaten
        end
      end

      def price_between(highest:, second:)
        AuctionMath.displayed_price(highest:, second:, starting_price: listing.starting_price, basis_points:)
      end

      def extension = listing.ends_at - now < settings.soft_close_seconds ? now + settings.soft_close_seconds : nil
    end
  end
end
