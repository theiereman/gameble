module Game
  # Closes the open trades 7 days after their last send or counter (AD-8),
  # on a schedule (config/recurring.yml): one Game::ExpireTrade per due
  # trade, each in its own transaction, for the trade's proposer (AD-14).
  # A trade answered, cancelled or countered meanwhile is refused by the
  # operation under its lock and left as it is; a trade whose expiry raises
  # is reported and skipped, so the others still expire. A rerun finds
  # nothing more to do.
  class ExpireTradesJob < ActiveJob::Base
    queue_as :default

    BATCH_SIZE = 100

    def perform
      Trade.due(Time.current).in_batches(of: BATCH_SIZE) do |batch|
        trades = batch.pluck(:id, :proposer_id)
        proposers = Accounts::Player.where(id: trades.map(&:last)).index_by(&:id)
        trades.each do |trade_id, proposer_id|
          ExpireTrade.new.call(player: proposers[proposer_id], trade_id:)
        rescue StandardError => error
          Rails.error.report(error, context: { trade_id: })
        end
      end
    end
  end
end
