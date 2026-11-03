module Game
  module TradesWaiting
    def self.call(player, now: Time.current)
      return 0 unless player

      relation(player, now:).count
    end

    def self.relation(player, now: Time.current)
      Trade.in_progress
        .where(recipient_id: player.id)
        .where(Trade.arel_table[:expires_at].gt(now))
        .where(proposer_id: Accounts::Player.in_good_standing.select(:id))
    end
  end
end
