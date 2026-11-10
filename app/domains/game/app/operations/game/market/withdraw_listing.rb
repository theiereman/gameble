module Game
  module Market
    class WithdrawListing < Operation
      include ListingEnding

      NOT_WITHDRAWABLE = Dry::Monads::Failure(:listing_not_withdrawable)

      def call(player:, listing_id:)
        player = step require_account(player)
        seen = step find_listing(player, listing_id)

        transaction do
          TradeLocks.players(*[ seen.seller_id, seen.leader_id ].compact)
          listing = Listing.lock.find(seen.id)
          step withdrawable(listing, seen)
          step end_without_sale(listing, "withdrawn", Time.current)
          listing
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def find_listing(player, listing_id)
        listing = Listing.find_by(id: listing_id, seller_id: player.id)
        listing ? Success(listing) : Failure(:listing_not_found)
      end

      def withdrawable(listing, seen)
        open = listing.status == "open" && listing.leader_id == seen.leader_id
        open && Accounts::Player.removed.exists?(id: listing.seller_id) ? Success() : NOT_WITHDRAWABLE
      end
    end
  end
end
