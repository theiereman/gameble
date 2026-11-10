module Game
  module Market
    module BidderListings
      Row = Data.define(:token, :card, :status, :price, :maximum, :ends_at, :ended_at, :can_raise)
      Groups = Data.define(:in_progress, :recent)

      WINDOW = 7.days
      COLUMNS = %i[id token status card_season_id current_price final_price ends_at sold_at leader_id].freeze
      ENDED_AT = "COALESCE(sold_at, ends_at)".freeze

      def self.call(player:, locale:)
        now = Time.current
        maxima = Bid.where(player_id: player.id).where.not(outcome: "voided").group(:listing_id).maximum(:maximum)
        listings = Listing.where(id: maxima.keys).where.not(status: "cancelled").where("status = 'open' OR #{ENDED_AT} >= ?", now - WINDOW).select(*COLUMNS).to_a
        cards = Catalog::CardViews.call(listings.map(&:card_season_id), locale:)
        rows = listings.filter_map { row(it, cards[it.card_season_id], maxima.fetch(it.id), player:, now:) }
        open, ended = rows.partition { it.ended_at.nil? }
        Groups.new(in_progress: open.sort_by(&:ends_at), recent: ended.sort_by(&:ended_at).reverse)
      end

      def self.row(listing, card, maximum, player:, now:)
        return unless card

        open = listing.status == "open"
        Row.new(token: listing.token, card:, status: status_of(listing, player), price: listing.status == "sold" ? listing.final_price : listing.current_price,
          maximum:, ends_at: listing.ends_at, ended_at: (listing.sold_at || listing.ends_at unless open), can_raise: open && listing.ends_at > now)
      end

      def self.status_of(listing, player)
        leads = listing.leader_id == player.id
        case listing.status
        when "open" then leads ? :leading : :outbid
        when "sold" then leads ? :won : :lost
        when "withdrawn" then :withdrawn
        else :lost
        end
      end

      private_class_method :row, :status_of
    end
  end
end
