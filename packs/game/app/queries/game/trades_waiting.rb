module Game
  # How many trades wait for the player's answer (CAP-11; EXPERIENCE.md,
  # Count badge: the orange badge of menu 03 and the ÉCHANGES tab), read at
  # render: open trades whose turn is the player's, not past their expiry,
  # from a proposer who is neither banned (AD-13) nor deleted (a deleted
  # partner's trade can no longer be accepted; story 5.11 closes it). 0 for
  # a visitor.
  #
  #   Game::TradesWaiting.call(player) # => 2
  module TradesWaiting
    def self.call(player, now: Time.current)
      return 0 unless player

      Trade.in_progress
        .where(recipient_id: player.id)
        .where(Trade.arel_table[:expires_at].gt(now))
        .where(proposer_id: Accounts::Player.where(banned_at: nil, deleted_at: nil).select(:id))
        .count
    end
  end
end
