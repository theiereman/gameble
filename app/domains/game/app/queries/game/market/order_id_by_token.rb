module Game
  module Market
    module OrderIdByToken
      def self.call(token) = Order.where(token: token.to_s).pick(:id)
    end
  end
end
