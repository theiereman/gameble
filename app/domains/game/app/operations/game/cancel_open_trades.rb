module Game
  class CancelOpenTrades < Operation
    include TradeSteps

    ATTEMPTS = 3

    def call(player:, partner: nil)
      player = step require_account(player)
      attempts = 0

      begin
        attempts += 1
        transaction(requires_new: true) { cancel(player, partner) }
      rescue ActiveRecord::Deadlocked
        retry if attempts < ATTEMPTS
        raise
      end
    end

    private

    def cancel(player, partner)
      now = Time.current
      trades = lock_open_trades(player, partner)
      release_offers(trades, now)
      Trade.where(id: trades.map(&:id)).update_all(status: "cancelled", closed_at: now, updated_at: now)
      trades
    end

    def open_trades(player, partner)
      proposed = Trade.in_progress.where(proposer_id: player.id)
      received = Trade.in_progress.where(recipient_id: player.id)
      return proposed.or(received) unless partner

      proposed.where(recipient_id: partner.id).or(received.where(proposer_id: partner.id))
    end

    # Postgres aborts one side of a deadlock, which `call` retries from its savepoint.
    def lock_open_trades(player, partner)
      held = []
      loop do
        missing = ([ player.id ] + open_trades(player, partner).pluck(:proposer_id, :recipient_id).flatten).uniq - held
        break if missing.empty?

        TradeLocks.players(*missing)
        held.concat(missing)
      end
      open_trades(player, partner).order(:id).lock.to_a
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
