module Game
  module Market
    class ExpireDueOrdersJob < ActiveJob::Base
      queue_as :default

      BATCH_SIZE = 100

      def perform
        Order.due(Time.current).in_batches(of: BATCH_SIZE) do |batch|
          orders = batch.pluck(:id, :player_id)
          owners = Accounts::Player.where(id: orders.map(&:last)).index_by(&:id)
          orders.each do |order_id, player_id|
            result = ExpireOrder.new.call(player: owners[player_id], order_id:)
            result.value! unless result == ExpireOrder::NOT_DUE
          rescue StandardError => error
            Rails.error.report(error, context: { order_id: })
          end
        end
      end
    end
  end
end
