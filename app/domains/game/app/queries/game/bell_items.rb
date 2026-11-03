module Game
  module BellItems
    PER_KIND = 5

    TradeLine = Data.define(:token, :player, :revision)
    InvitationLine = Data.define(:token, :player)
    GoalLine = Data.define(:week_start, :reward_ready, :target, :reached)
    Result = Data.define(:trades, :invitations, :daily, :goal)

    def self.call(player, now: Time.current)
      trades = trades_waiting(player, now).to_a
      invitations = invitations_waiting(player).to_a
      senders = Accounts::Player.where(id: trades.map(&:proposer_id) | invitations.map(&:sender_id)).index_by(&:id)

      Result.new(
        trades: trades.map { TradeLine.new(token: it.token, player: senders[it.proposer_id], revision: it.revision) },
        invitations: invitations.map { InvitationLine.new(token: it.token, player: senders[it.sender_id]) },
        daily: daily(player, now),
        goal: goal(player, now)
      )
    end

    def self.trades_waiting(player, now)
      TradesWaiting.relation(player, now:)
        .order(:expires_at, :id)
        .limit(PER_KIND)
        .select(:id, :token, :proposer_id, :proposed_at)
    end
    private_class_method :trades_waiting

    def self.invitations_waiting(player)
      InvitationsWaiting.relation(player)
        .order(id: :desc)
        .limit(PER_KIND)
        .select(:id, :token, :sender_id)
    end
    private_class_method :invitations_waiting

    def self.daily(player, now)
      day = DailyBonusClaim.day_of(now)
      return if DailyBonusClaim.exists?(player_id: player.id, day:)

      day if Catalog::PublishedSeason.call.present?
    end
    private_class_method :daily

    def self.goal(player, now)
      reward = GoalRewardStatus.call(player, now:)
      if reward && !reward[:claimed]
        GoalLine.new(week_start: reward[:week_start], reward_ready: true, target: nil, reached: true)
      else
        week = CurrentGoal.call(now:)
        GoalLine.new(week_start: WeeklyGoal.week_start(now), reward_ready: false, target: week[:target], reached: week[:reached])
      end
    end
    private_class_method :goal
  end
end
