module Game
  module Market
    # The Annonce's history, newest first: the public bids, the viewer's own raises and the listing's creation. It never reads a maximum.
    module BidHistory
      Line = Data.define(:kind, :player, :price, :at, :until, :leading)

      COLUMNS = %i[id player_id price_after outcome extended_until created_at].freeze

      def self.call(token:, viewer:)
        listing = Listing.where(token: token.to_s).select(:id, :seller_id, :status, :leader_id, :created_at).first
        return [] unless listing

        rows = visible_rows(token, viewer)
        players = Accounts::Player.where(id: [ listing.seller_id, *rows.map(&:player_id) ]).index_by(&:id)
        lines = rows.flat_map { |row| lines_of(row, players.fetch(row.player_id), listing) }
        lines << Line.new(kind: :created, player: players.fetch(listing.seller_id), price: nil, at: listing.created_at, until: nil, leading: false)
      end

      def self.visible_rows(token, viewer)
        visible = Bid.public_outcomes
        visible = visible.or(Bid.where(outcome: "raise", player_id: viewer.id)) if viewer
        visible.joins(:listing).where(game_market_listings: { token: token.to_s }).select(*COLUMNS).order(id: :desc).to_a
      end

      def self.lines_of(row, player, listing)
        return [ Line.new(kind: :raise, player:, price: nil, at: row.created_at, until: nil, leading: false) ] if row.outcome == "raise"

        leading = listing.status == "open" && row.outcome == "leading" && row.player_id == listing.leader_id
        lines = [ Line.new(kind: :bid, player:, price: row.price_after, at: row.created_at, until: nil, leading:) ]
        lines.unshift(Line.new(kind: :extension, player: nil, price: nil, at: row.created_at, until: row.extended_until, leading: false)) if row.extended_until
        lines
      end

      private_class_method :visible_rows, :lines_of
    end
  end
end
