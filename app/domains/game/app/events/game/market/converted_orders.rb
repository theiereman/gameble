module Game
  module Market
    # The orders an auction opening turned into bids, as a stored event names them; events written before the conversion carry none.
    module ConvertedOrders
      def self.rows(data) = data.fetch(:converted, [])

      def self.owner_ids(data) = rows(data).map { it.fetch(:owner_id) }
    end
  end
end
