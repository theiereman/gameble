module Game
  module Market
    module WantedCardIds
      def self.call(player)
        return [] if player.nil?

        Wanted.where(player_id: player.id).distinct.order(:card_id).pluck(:card_id)
      end
    end
  end
end
