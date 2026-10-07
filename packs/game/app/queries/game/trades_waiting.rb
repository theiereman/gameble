module Game
  # How many trades wait for the player's answer (CAP-11; EXPERIENCE.md,
  # Count badge: the orange badge of menu 03 and the ÉCHANGES tab), read at
  # render: open trades whose turn is the player's, not past their expiry,
  # from a proposer who is not banned (AD-13). 0 for a visitor.
  #
  #   Game::TradesWaiting.call(player) # => 2
  module TradesWaiting
    def self.call(player, now: Time.current)
      return 0 unless player

      Trade.in_progress
        .where(recipient_id: player.id)
        .where(Trade.arel_table[:expires_at].gt(now))
        .where(proposer_id: Accounts::Player.where(banned_at: nil).select(:id))
        .count
    end
  end
end
