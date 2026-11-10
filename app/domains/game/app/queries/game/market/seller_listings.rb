module Game
  module Market
    # A seller's own listings for MES VENTES, in two groups. The only reader of what a seller received per sale and of the copies that can be relisted.
    module SellerListings
      Relist = Data.define(:ref, :start, :buy_now)
      Row = Data.define(:token, :card, :status, :current_price, :ends_at, :ended_at, :received, :can_cancel, :relist)
      Groups = Data.define(:in_progress, :ended)

      WINDOW = 30.days
      LIMIT = 100
      ENDED_AT = "(CASE status WHEN 'sold' THEN sold_at WHEN 'unsold' THEN ends_at ELSE updated_at END)".freeze
      COLUMNS = %i[id token status card_season_id current_price final_price starting_price buy_now_price ends_at sold_at updated_at leader_id].freeze

      def self.call(player:, locale:)
        now = Time.current
        listings = Listing.where(seller_id: player.id)
        open = listings.where(status: "open").order(:ends_at, :id).select(*COLUMNS).to_a
        ended = listings.where(status: %w[sold unsold cancelled withdrawn]).where("#{ENDED_AT} >= ?", now - WINDOW)
          .order(Arel.sql("#{ENDED_AT} DESC"), id: :desc).limit(LIMIT).select(*COLUMNS).to_a
        cards = Catalog::CardViews.call((open + ended).map(&:card_season_id), locale:)
        received = received_by(player, ended.select { it.status == "sold" })
        relistable = relistable_among(player, ended.select { it.status == "unsold" })
        build = ->(listing) { row(listing, cards[listing.card_season_id], now:, received:, relistable:) }
        Groups.new(in_progress: open.filter_map(&build), ended: ended.filter_map(&build))
      end

      def self.row(listing, card, now:, received:, relistable:)
        return unless card

        Row.new(token: listing.token, card:, status: listing.status, current_price: price_of(listing), ends_at: listing.ends_at,
          ended_at: listing.status == "open" ? nil : ended_at(listing), received: received[listing.id],
          can_cancel: listing.status == "open" && listing.leader_id.nil? && listing.ends_at > now,
          relist: (relist(listing, card) if relistable.include?(listing.id)))
      end

      def self.price_of(listing) = listing.status == "sold" ? listing.final_price : listing.current_price

      def self.ended_at(listing)
        case listing.status
        when "sold" then listing.sold_at
        when "unsold" then listing.ends_at
        else listing.updated_at
        end
      end

      def self.relist(listing, card)
        Relist.new(ref: EntrustableCopies.ref(card.id, card.season_number), start: listing.starting_price, buy_now: listing.buy_now_price)
      end

      def self.received_by(player, sold)
        return {} if sold.empty?

        LedgerEntry.where(listing_id: sold.map(&:id), player_id: player.id, kind: %w[sale commission]).group(:listing_id).sum(:available_delta)
      end

      def self.relistable_among(player, unsold)
        return [] if unsold.empty?

        editions = unsold.map(&:card_season_id).uniq
        latest = Listing.where(seller_id: player.id, card_season_id: editions).group(:card_season_id).maximum(:id)
        free = Holding.where(player_id: player.id, card_season_id: editions).where("quantity > reserved").pluck(:card_season_id)
        unsold.select { latest[it.card_season_id] == it.id && free.include?(it.card_season_id) }.map(&:id)
      end

      private_class_method :row, :price_of, :ended_at, :relist, :received_by, :relistable_among
    end
  end
end
