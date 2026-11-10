module Game
  module Market
    class VoidLead < Operation
      LEAD_NOT_VOIDABLE = Dry::Monads::Failure(:lead_not_voidable)

      def call(player:, listing_id:)
        player = step require_account(player)
        seen = step find_listing(player, listing_id)

        transaction do
          TradeLocks.players(seen.seller_id, seen.leader_id)
          listing = Listing.lock.find(seen.id)
          step voidable(listing, seen, Time.current)
          void(listing)
          listing
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def find_listing(player, listing_id)
        listing = Listing.find_by(id: listing_id, seller_id: player.id)
        return Failure(:listing_not_found) unless listing

        listing.leader_id ? Success(listing) : LEAD_NOT_VOIDABLE
      end

      def voidable(listing, seen, now)
        open = listing.status == "open" && listing.ends_at > now
        open && listing.leader_id == seen.leader_id && Accounts::Player.removed.exists?(id: listing.leader_id) ? Success() : LEAD_NOT_VOIDABLE
      end

      def void(listing)
        leader_id = listing.leader_id
        released = listing.leader_maximum
        Bid.displace(listing_id: listing.id, player_id: leader_id)
        listing.update!(leader_id: nil, leader_maximum: nil, current_price: listing.starting_price)
        Bid.create!(listing:, player_id: leader_id, maximum: released, price_after: listing.starting_price, outcome: "voided")
        Ledger.post(Ledger::Entry.new(player_id: leader_id, kind: :release, available_delta: released, committed_delta: -released, listing_id: listing.id,
          settings_id: listing.settings_id))
        step publish(LeadVoided.new(data: { listing_id: listing.id, seller_id: listing.seller_id, leader_id:, released: }), stream_name: stream_name(listing.seller_id))
      end
    end
  end
end
