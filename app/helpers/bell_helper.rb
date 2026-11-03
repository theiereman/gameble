module BellHelper
  BellLine = Data.define(:key, :path, :href, :sentence, :action, :lasting, :dom_id) do
    def initialize(lasting: false, dom_id: nil, **line) = super(lasting:, dom_id:, **line)
  end

  def bell_lines(items)
    [
      *items.trades.map { bell_trade_line(it) },
      *items.updates.map { bell_trade_update_line(it) },
      *items.invitations.map { bell_invitation_line(it) },
      (bell_daily_line(items.daily) if items.daily),
      bell_goal_line(items.goal)
    ].compact
  end

  def bell_trade_line(trade)
    path = trade_path(token: trade.token)
    BellLine.new(key: "trade:#{trade.token}:#{trade.revision}", path:, href: path,
      sentence: t("shell.bell.trade", name: friend_name(trade.player)), action: t("shell.bell.answer"))
  end

  def bell_trade_update_line(update)
    path = trade_path(token: update.token)
    BellLine.new(key: "trade-update:#{update.token}:#{update.closed_at.utc.iso8601(6)}", path:, href: path,
      sentence: t("shell.bell.trade_#{update.outcome}", name: friend_name(update.player)), action: t("shell.bell.see"))
  end

  def bell_invitation_line(invitation)
    BellLine.new(key: "invitation:#{invitation.token}", path: friends_path, href: friends_path,
      sentence: t("shell.bell.invitation", name: friend_name(invitation.player)), action: t("shell.bell.see"))
  end

  def bell_daily_line(day)
    BellLine.new(key: "daily:#{day.iso8601}", path: booster_path, href: booster_path,
      sentence: t("shell.bell.daily"), action: t("shell.bell.collect"), lasting: true, dom_id: "bell-daily")
  end

  def bell_goal_line(goal)
    href = social_path(anchor: "community-goal")
    if goal.reward_ready
      BellLine.new(key: "mission-reward:#{goal.week_start.iso8601}", path: social_path, href:,
        sentence: t("shell.bell.mission_reward"), action: t("shell.bell.collect"), lasting: true, dom_id: "bell-mission-reward")
    else
      sentence = t(goal.reached ? "shell.bell.mission_reached" : "shell.bell.mission", target: number_with_delimiter(goal.target))
      BellLine.new(key: "mission:#{goal.week_start.iso8601}", path: social_path, href:, sentence:, action: t("shell.bell.see"))
    end
  end
end
