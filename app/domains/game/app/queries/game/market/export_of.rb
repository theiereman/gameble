module Game
  module Market
    module ExportOf
      EntryRow = Data.define(:kind, :available_delta, :committed_delta, :listing_token, :order_token, :created_at)
      ListingRow = Data.define(:token, :card_season_id, :status, :starting_price, :current_price, :final_price, :duration_hours, :created_at,
        :ends_at, :sold_at)
      BidRow = Data.define(:listing_token, :maximum, :price_after, :outcome, :created_at)
      OrderRow = Data.define(:token, :card_slug, :status, :price, :created_at, :expires_at, :served_card_season_id, :served_at)
      SaleToOrderRow = Data.define(:card_season_id, :price, :served_at)
      ArchivePurchaseRow = Data.define(:card_season_id, :price, :created_at)
      SlotRow = Data.define(:kind, :bought)
      Result = Data.define(:wallet, :entries, :listings, :bids, :orders, :sales_to_orders, :archive_purchases, :bought_slots) do
        def card_season_ids
          (listings.map(&:card_season_id) + orders.filter_map(&:served_card_season_id) + sales_to_orders.map(&:card_season_id) +
            archive_purchases.map(&:card_season_id)).uniq
        end
      end

      LISTING_COLUMNS = %i[token card_season_id status starting_price current_price final_price duration_hours created_at ends_at sold_at].freeze

      def self.call(player)
        entries = LedgerEntry.where(player_id: player.id).order(:created_at, :id).pluck(:kind, :available_delta, :committed_delta, :listing_id, :order_id, :created_at)
        bids = Bid.where(player_id: player.id).order(:created_at, :id).pluck(:listing_id, :maximum, :price_after, :outcome, :created_at)
        tokens = Listing.where(id: (entries.map { it[3] } + bids.map(&:first)).compact.uniq).pluck(:id, :token).to_h
        orders = Order.where(player_id: player.id).order(:created_at, :id)
          .pluck(:id, :token, :card_id, :status, :price, :created_at, :expires_at, :served_card_season_id, :served_at)
        own_order_tokens = orders.to_h { it.first(2) }
        slugs = Catalog::PublishedCardIds.slugs(orders.map { it[2] })
        Result.new(
          wallet: Balance.call(player),
          entries: entries.map do |kind, available, committed, listing_id, order_id, at|
            EntryRow.new(kind:, available_delta: available, committed_delta: committed, listing_token: tokens[listing_id], order_token: own_order_tokens[order_id], created_at: at)
          end,
          listings: Listing.where(seller_id: player.id).order(:created_at, :id).pluck(*LISTING_COLUMNS).map { ListingRow.new(*it) },
          bids: bids.map { |listing_id, maximum, price_after, outcome, at| BidRow.new(listing_token: tokens.fetch(listing_id), maximum:, price_after:, outcome:, created_at: at) },
          orders: orders.map { |_id, token, card_id, *rest| OrderRow.new(token, slugs[card_id], *rest) },
          sales_to_orders: Order.where(seller_id: player.id).order(:served_at, :id).pluck(:served_card_season_id, :price, :served_at).map { SaleToOrderRow.new(*it) },
          archive_purchases: ArchiveWithdrawal.where(player_id: player.id).order(:created_at, :id).pluck(:card_season_id, :price, :created_at).map { ArchivePurchaseRow.new(*it) },
          bought_slots: CapacitySlot.where(player_id: player.id).order(:kind).pluck(:kind, :bought).map { SlotRow.new(*it) }
        )
      end
    end
  end
end
