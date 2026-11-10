module Game
  module Market
    module AltSignals
      # An accepted trade never has an empty side, so a trade is one-way when one side gives many times what it gets.
      module OneWayTrades
        OFFERED = "COALESCE(SUM(game_trade_items.quantity) FILTER (WHERE game_trade_items.side = 'offer'), 0)".freeze
        REQUESTED = "COALESCE(SUM(game_trade_items.quantity) FILTER (WHERE game_trade_items.side = 'request'), 0)".freeze

        def self.call(now:)
          trades = Trade.where(status: "accepted", closed_at: (now - ONE_WAY_WINDOW_DAYS.days)..now).joins(:items)
            .group("game_trades.id", "game_trades.proposer_id", "game_trades.recipient_id")
            .pluck("game_trades.proposer_id", "game_trades.recipient_id", Arel.sql(OFFERED), Arel.sql(REQUESTED))
          trades.filter_map { giving(*it) }.group_by(&:first).filter_map { |pair, one_way| detected(pair, one_way) }
        end

        def self.giving(proposer_id, recipient_id, offered, requested)
          return [ [ proposer_id, recipient_id ], offered, requested ] if offered.positive? && offered >= requested * ONE_WAY_COPIES_RATIO
          return [ [ recipient_id, proposer_id ], requested, offered ] if requested.positive? && requested >= offered * ONE_WAY_COPIES_RATIO
        end

        def self.detected(pair, one_way)
          return if one_way.size < ONE_WAY_TRADES_REQUIRED

          Detected.new(account_id: pair.first, signal: "one_way_trades", other_account_id: pair.last,
            facts: { "trades" => one_way.size, "given" => one_way.sum { it[1] }, "received" => one_way.sum { it[2] } })
        end

        private_class_method :giving, :detected
      end
    end
  end
end
