module Game
  module Market
    module OrderIdByToken
      def self.call(token) = Order.where(token: token.to_s).pick(:id)

      def self.on_card(token, card_id) = Order.where(token: token.to_s, card_id:).pick(:id)
    end
  end
end
