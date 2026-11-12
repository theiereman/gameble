module Game
  module Market
    class PlaceBid < Operation
      include PriceAmount

      def call(player:, listing_id:, maximum:)
        player = step require_player(player)
        maximum = step amount(maximum)
        seen = step find_listing(listing_id)

        transaction do
          TradeLocks.players(player.id)
          step still_present(player)
          listing = Listing.lock.find(seen.id)
          now = Time.current
          step biddable(listing, player, now)
          terms = BidTerms.new(listing:, player:, maximum:, settings: Settings.find(listing.settings_id), now:, leader: present_leader(listing), displaced: displaced_by(listing, player))
          step covered(terms)
          place(terms)
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def find_listing(listing_id)
        listing = Listing.find_by(id: listing_id)
        listing ? Success(listing) : Failure(:listing_not_found)
      end

      def still_present(player) = Accounts::Player.find(player.id).removed? ? Failure(:player_required) : Success()

      def biddable(listing, player, now)
        return Failure(:market_closed) unless CurrentSettings.call&.open
        return Failure(:auction_ended) unless listing.status == "open" && listing.ends_at > now
        return Failure(:listing_withdrawn) if Accounts::Player.find(listing.seller_id).removed?

        listing.seller_id == player.id ? Failure(:own_listing) : Success()
      end

      def present_leader(listing)
        return unless listing.leader_id

        Accounts::Player.find(listing.leader_id).removed? ? nil : BidTerms.lead_of(listing.leader_id, listing.leader_maximum)
      end

      def displaced_by(listing, player)
        listing.leader_id == player.id ? nil : BidTerms.lead_of(listing.leader_id, listing.leader_maximum)
      end

      def covered(terms)
        return Failure(:below_minimum) if terms.maximum < terms.minimum

        Balance.call(terms.player).available >= terms.needed ? Success() : Failure(:more_than_available)
      end

      def place(terms)
        branch = terms.branch
        Ledger.post(send(:"on_#{branch}", terms))
        publish_bid(terms, branch)
        answer(terms, branch)
      end

      def on_new_leader(terms)
        listing = terms.listing
        price = terms.price_between(highest: terms.maximum, second: terms.leader&.maximum)
        Bid.displace(listing_id: listing.id, player_id: terms.displaced.player_id) if terms.displaced
        extended = terms.extension
        listing.update!(leader_id: terms.player.id, leader_maximum: terms.maximum, current_price: price, ends_at: extended || listing.ends_at)
        record(terms, outcome: "leading", price_after: price, extended_until: extended)
        [ *hold(terms, terms.maximum), *release(terms, terms.displaced) ]
      end

      def on_beaten(terms)
        listing = terms.listing
        price = terms.price_between(highest: terms.leader.maximum, second: terms.maximum)
        extended = terms.extension
        listing.update!(current_price: price, ends_at: extended || listing.ends_at)
        record(terms, outcome: "beaten", price_after: price, extended_until: extended)
        []
      end

      def on_raise(terms)
        listing = terms.listing
        listing.update!(leader_maximum: terms.maximum)
        record(terms, outcome: "raise", price_after: listing.current_price)
        hold(terms, terms.needed)
      end

      def record(terms, outcome:, price_after:, extended_until: nil)
        Bid.create!(listing: terms.listing, player: terms.player, maximum: terms.maximum, price_after:, outcome:, extended_until:)
      end

      def hold(terms, amount)
        amount.positive? ? [ entry(terms, terms.player.id, :hold, -amount, amount) ] : []
      end

      def release(terms, lead)
        lead ? [ entry(terms, lead.player_id, :release, lead.maximum, -lead.maximum) ] : []
      end

      def entry(terms, player_id, kind, available, committed)
        Ledger::Entry.new(player_id:, kind:, available_delta: available, committed_delta: committed, listing_id: terms.listing.id, settings_id: terms.listing.settings_id)
      end

      def publish_bid(terms, branch)
        outbid = branch == :new_leader ? terms.displaced : nil
        event = BidPlaced.new(data: { listing_id: terms.listing.id, bidder_id: terms.player.id, branch: branch.to_s,
          outbid_player_id: outbid&.player_id, outbid_released: outbid ? outbid.maximum : 0 })
        publish(event, stream_name: stream_name(terms.player.id))
      end

      def answer(terms, branch)
        listing = terms.listing.reload
        minimum = AuctionMath.minimum_bid(price: listing.current_price, starting_price: listing.starting_price, basis_points: terms.basis_points)
        BidAnswer.new(branch:, equal_maximum: branch == :beaten && terms.maximum == terms.leader.maximum, price: listing.current_price,
          maximum: branch == :beaten ? nil : listing.leader_maximum, minimum:, listing:)
      end
    end
  end
end
