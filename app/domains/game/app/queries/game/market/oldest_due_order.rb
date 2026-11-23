module Game
  module Market
    module OldestDueOrder
      def self.call(now: Time.current)
        expires_at = Order.due(now).minimum(:expires_at)
        (now - expires_at).to_i if expires_at
      end
    end
  end
end
