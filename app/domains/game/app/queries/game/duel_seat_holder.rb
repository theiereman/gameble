module Game
  module DuelSeatHolder
    def self.call(stream_key)
      return nil unless stream_key.is_a?(String) && stream_key.present?

      DuelSeat.where(stream_key:).pick(:player_id)
    end
  end
end
