module Game
  # A player's friends (AD-8): the players on the other side of their
  # friendships, banned ones left out (AD-13), by name, deleted ones too
  # (their friendships go with the deletion, Game::DropFriendsAndTrades;
  # this covers an acceptance racing it). Empty for a visitor.
  #
  #   Game::FriendsOf.call(player) # => [Accounts::Player, ...]
  module FriendsOf
    def self.call(player)
      return [] unless player

      ids = Friendship.of(player.id).pluck(:low_player_id, :high_player_id).flatten.uniq - [ player.id ]
      Accounts::Player.where(id: ids, banned_at: nil, deleted_at: nil).order(:persona_name, :id).to_a
    end
  end
end
