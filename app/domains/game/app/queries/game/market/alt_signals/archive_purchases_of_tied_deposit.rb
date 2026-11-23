module Game
  module Market
    module AltSignals
      module ArchivePurchasesOfTiedDeposit
        DEPOSITS = <<~SQL.squish.freeze
          JOIN game_market_archive_deposits deposits ON deposits.card_season_id = game_market_archive_withdrawals.card_season_id
            AND deposits.player_id <> game_market_archive_withdrawals.player_id AND deposits.updated_at >= :since
        SQL

        def self.call(now:, ties:)
          return [] if ties.empty?

          since = now - MARKET_WINDOW_DAYS.days
          purchases = ArchiveWithdrawal.where(created_at: since..).joins(ArchiveWithdrawal.sanitize_sql_array([ DEPOSITS, { since: } ]))
            .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_archive_withdrawals.card_season_id")
            .joins("JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id")
            .joins("JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id")
            .order(:created_at, :id, "deposits.player_id")
            .pluck(:player_id, "deposits.player_id", :price, "catalog_cards.slug", "catalog_seasons.number", "deposits.quantity", "deposits.updated_at")
          purchases.filter_map { detected(*it, ties) }
        end

        def self.detected(buyer_id, depositor_id, price, card, season, deposited, deposited_at, ties)
          return unless ties.include?([ buyer_id, depositor_id ].minmax)

          Detected.new(account_id: buyer_id, signal: "archive_purchase_of_tied_deposit", other_account_id: depositor_id,
            facts: { "card" => card, "season" => season, "price" => price, "deposited" => deposited, "deposited_on" => deposited_at.utc.to_date.iso8601 })
        end

        private_class_method :detected
      end
    end
  end
end
