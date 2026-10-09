module Game
  class CancelOpenTrades < Operation
    include TradeSteps

    ATTEMPTS = 3

    def call(player:)
      player = step require_account(player)
      attempts = 0

      begin
        attempts += 1
        transaction(requires_new: true) { cancel(player) }
      rescue ActiveRecord::Deadlocked
        retry if attempts < ATTEMPTS
        raise
      end
    end

    private

    def cancel(player)
      now = Time.current
      trades = lock_open_trades(player)
      release_offers(trades, now)
      Trade.where(id: trades.map(&:id)).update_all(status: "cancelled", closed_at: now, updated_at: now)
      trades
    end

    def open_trades(player)
      Trade.in_progress.where(proposer_id: player.id).or(Trade.in_progress.where(recipient_id: player.id))
    end

    # A partner found after the player's own lock is locked out of order; Postgres aborts one side of a deadlock, which `call` retries from its savepoint.
    def lock_open_trades(player)
      held = []
      loop do
        missing = ([ player.id ] + open_trades(player).pluck(:proposer_id, :recipient_id).flatten).uniq - held
        break if missing.empty?

        TradeLocks.players(*missing)
        held.concat(missing)
      end
      open_trades(player).order(:id).lock.to_a
    end

    def release_offers(trades, now)
      proposers = trades.to_h { |trade| [ trade.id, trade.proposer_id ] }
      lines = TradeItem.where(trade_id: proposers.keys, side: "offer").pluck(:trade_id, :card_season_id, :quantity)
      lines.group_by { |trade_id, _, _| proposers.fetch(trade_id) }.sort.each do |proposer_id, offered|
        offer = offered.each_with_object(Hash.new(0)) { |(_, card_season_id, quantity), sum| sum[card_season_id] += quantity }
        release(offer, TradeLocks.holdings(proposer_id, offer.keys), now)
      end
    end
  end
end
