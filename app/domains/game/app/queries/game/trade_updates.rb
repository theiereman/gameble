module Game
  # The trades a player proposed that the friend accepted or declined, until the player opens them.
  module TradeUpdates
    WINDOW = 7.days
    PER_KIND = 5

    def self.call(player, now: Time.current)
      return [] unless player

      relation(player, now:).order(closed_at: :desc, id: :desc).limit(PER_KIND).select(:id, :token, :recipient_id, :status, :closed_at).to_a
    end

    def self.unseen?(player, token, now: Time.current)
      return false unless player && token.is_a?(String)

      relation(player, now:).exists?(token:)
    end

    def self.relation(player, now: Time.current)
      Trade.where(proposer_id: player.id, status: %w[accepted declined])
        .where(Trade.arel_table[:closed_at].gteq(now - WINDOW))
        .where(recipient_id: Accounts::Player.in_good_standing.select(:id))
        .where.not(seen_since_closing(player))
    end

    def self.seen_since_closing(player)
      views = TradeView.arel_table
      trades = Trade.arel_table
      TradeView.where(player_id: player.id).where(views[:trade_id].eq(trades[:id])).where(views[:seen_at].gteq(trades[:closed_at])).arel.exists
    end
    private_class_method :seen_since_closing
  end
end
