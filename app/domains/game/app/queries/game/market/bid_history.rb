module Game
  module Market
    module BidHistory
      Line = Data.define(:kind, :player, :price, :at, :until, :leading, :leader) do
        def initialize(leader: nil, **) = super
      end

      COLUMNS = %i[id player_id price_after outcome extended_until created_at].freeze
      TOOK_THE_LEAD = %w[leading outbid].freeze

      def self.call(token:, viewer:)
        listing = Listing.where(token: token.to_s).select(:id, :seller_id, :status, :leader_id, :created_at).first
        return [] unless listing

        rows = visible_rows(token, viewer)
        covered = covering_leaders(rows.reverse)
        players = Accounts::Player.where(id: [ listing.seller_id, *rows.map(&:player_id) ]).index_by(&:id)
        lines = rows.flat_map { |row| lines_of(row, players, listing, covered[row.id]) }
        lines << Line.new(kind: :created, player: players.fetch(listing.seller_id), price: nil, at: listing.created_at, until: nil, leading: false)
      end

      def self.visible_rows(token, viewer)
        visible = Bid.history_visible
        visible = visible.or(Bid.where(outcome: "raise", player_id: viewer.id)) if viewer
        visible.joins(:listing).where(game_market_listings: { token: token.to_s }).select(*COLUMNS).order(id: :desc).to_a
      end

      def self.covering_leaders(oldest_first)
        leader = nil
        oldest_first.each_with_object({}) do |row, covered|
          leader = row.player_id if TOOK_THE_LEAD.include?(row.outcome)
          covered[row.id] = leader if row.outcome == "beaten" && leader
        end
      end

      def self.lines_of(row, players, listing, covering_leader_id)
        player = players.fetch(row.player_id)
        return [ Line.new(kind: :voided, player: nil, price: nil, at: row.created_at, until: nil, leading: false) ] if row.outcome == "voided"
        return [ Line.new(kind: :raise, player:, price: nil, at: row.created_at, until: nil, leading: false) ] if row.outcome == "raise"

        lines = if covering_leader_id
          [ Line.new(kind: :covered, player:, price: row.price_after, at: row.created_at, until: nil, leading: false, leader: players.fetch(covering_leader_id)) ]
        else
          leading = listing.status == "open" && row.outcome == "leading" && row.player_id == listing.leader_id
          [ Line.new(kind: :bid, player:, price: row.price_after, at: row.created_at, until: nil, leading:) ]
        end
        lines.unshift(Line.new(kind: :extension, player: nil, price: nil, at: row.created_at, until: row.extended_until, leading: false)) if row.extended_until
        lines
      end

      private_class_method :visible_rows, :covering_leaders, :lines_of
    end
  end
end
