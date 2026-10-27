module Game
  module FriendCodeOf
    def self.call(player)
      return nil unless player

      FriendCode.where(player_id: player.id).pick(:code)
    end
  end
end
