module Game
  # A player's friend code, as the string XXXX-XXXX, or nil when they have
  # none yet (before the backfill) or are a visitor (AD-8).
  #
  #   Game::FriendCodeOf.call(player) # => "7K2Q-F3NX"
  module FriendCodeOf
    def self.call(player)
      return nil unless player

      FriendCode.where(player_id: player.id).pick(:code)
    end
  end
end
