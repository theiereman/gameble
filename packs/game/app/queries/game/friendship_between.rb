module Game
  # Whether two players are friends (AD-8): one friendship row for the pair,
  # the lower player id first. False, without a query, for a missing player
  # (a visitor) or a player and themselves. Game::Visibility asks it for a
  # friends-only owner; the friend profile asks it before anything is shown.
  #
  #   Game::FriendshipBetween.call(player, other) # => true | false
  module FriendshipBetween
    def self.call(player, other)
      return false if player.nil? || other.nil? || player.id == other.id

      low, high = [ player.id, other.id ].minmax
      Friendship.exists?(low_player_id: low, high_player_id: high)
    end
  end
end
