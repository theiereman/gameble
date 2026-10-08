module Game
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
