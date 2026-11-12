module Game
  module Market
    module ExportOf
      EntryRow = Data.define(:kind, :available_delta, :committed_delta, :listing_token, :created_at)
      ListingRow = Data.define(:token, :card_season_id, :status, :starting_price, :current_price, :final_price, :duration_hours, :created_at,
        :ends_at, :sold_at)
      BidRow = Data.define(:listing_token, :maximum, :price_after, :outcome, :created_at)
      Result = Data.define(:wallet, :entries, :listings, :bids) do
        def card_season_ids = listings.map(&:card_season_id).uniq
      end

      LISTING_COLUMNS = %i[token card_season_id status starting_price current_price final_price duration_hours created_at ends_at sold_at].freeze

      def self.call(player)
        entries = LedgerEntry.where(player_id: player.id).order(:created_at, :id).pluck(:kind, :available_delta, :committed_delta, :listing_id, :created_at)
        bids = Bid.where(player_id: player.id).order(:created_at, :id).pluck(:listing_id, :maximum, :price_after, :outcome, :created_at)
        tokens = Listing.where(id: (entries.map { it[3] } + bids.map(&:first)).compact.uniq).pluck(:id, :token).to_h
        Result.new(
          wallet: Balance.call(player),
          entries: entries.map { |kind, available, committed, listing_id, at| EntryRow.new(kind:, available_delta: available, committed_delta: committed, listing_token: tokens[listing_id], created_at: at) },
          listings: Listing.where(seller_id: player.id).order(:created_at, :id).pluck(*LISTING_COLUMNS).map { ListingRow.new(*it) },
          bids: bids.map { |listing_id, maximum, price_after, outcome, at| BidRow.new(listing_token: tokens.fetch(listing_id), maximum:, price_after:, outcome:, created_at: at) }
        )
      end
    end
  end
end
