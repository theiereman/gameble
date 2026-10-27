module Game
  module FriendshipBetween
    def self.call(player, other)
      return false if player.nil? || other.nil? || player.id == other.id

      low, high = [ player.id, other.id ].minmax
      Friendship.exists?(low_player_id: low, high_player_id: high)
    end
  end
end
