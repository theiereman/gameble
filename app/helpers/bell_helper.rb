module BellHelper
  MARKET_TARGETS = { outbid: :annonce, won: :annonce, sold: :sales, unsold: :sales, lead_voided: :sales, withdrawn: :annonce }.freeze

  BellLine = Data.define(:key, :path, :href, :sentence, :action, :lasting, :dom_id, :reactions, :subject, :read) do
    def initialize(lasting: false, dom_id: nil, reactions: {}, subject: nil, read: false, **line) = super(lasting:, dom_id:, reactions:, subject:, read:, **line)
  end

  def bell_lines(items)
    [
      *items.trades.map { bell_trade_line(it) },
      *items.updates.map { bell_trade_update_line(it) },
      *items.invitations.map { bell_invitation_line(it) },
      *items.reactions.map { bell_reaction_line(it) },
      *items.duels.map { bell_duel_line(it) },
      *items.market.filter_map { bell_market_line(it) },
      *items.orders.map { bell_order_line(it) },
      (bell_wanted_line(items.wanted) if items.wanted),
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

  def bell_duel_line(duel)
    path = duel_path(token: duel.token)
    if duel.kind == :resume
      BellLine.new(key: "duel-resume:#{duel.token}", path:, href: path, sentence: t("shell.bell.duel_resume", name: duel_plain_name(duel.opponent)),
        action: t("shell.bell.resume"), lasting: true, dom_id: "bell-duel-resume")
    else
      BellLine.new(key: "duel:#{duel.token}", path:, href: path, action: t("shell.bell.see"),
        sentence: t("shell.bell.duel_finished", name: duel_plain_name(duel.opponent), outcome: t("shell.bell.duel_outcome.#{duel.outcome}"),
          score: duel.score, other_score: duel.other_score))
    end
  end

  def bell_invitation_line(invitation)
    BellLine.new(key: "invitation:#{invitation.token}", path: friends_path, href: friends_path,
      sentence: t("shell.bell.invitation", name: friend_name(invitation.player)), action: t("shell.bell.see"))
  end

  def bell_reaction_line(reaction)
    sentence = if reaction.name
      t("shell.bell.reaction_named", name: reaction.name, count: reaction.others)
    else
      t("shell.bell.reaction_anonymous", count: reaction.count)
    end
    href = feed_path(entry: reaction.token, anchor: "entry-#{reaction.token}")
    BellLine.new(key: "reaction:#{reaction.token}:#{reaction.noticed_at.utc.iso8601(6)}", path: nil, href:, sentence:,
      action: t("shell.bell.see"), reactions: reaction.kinds, subject: bell_reaction_subject(reaction.subject))
  end

  def bell_market_line(notice)
    target = MARKET_TARGETS[notice.kind]
    return unless target

    path = target == :annonce ? market_listing_path(token: notice.token) : market_my_sales_path
    sentence = t("shell.bell.market.#{notice.kind}_html", card: notice.card, amount: render(PicoinAmountComponent.new(amount: notice.amount.to_i)),
      name: (render(PlayerNameComponent.new(player: notice.other, viewer: nil, linked: false)) if notice.other))
    BellLine.new(key: "market:#{notice.token}:#{notice.noticed_at.utc.iso8601(6)}", path:, href: path, sentence:, action: t("shell.bell.see"))
  end

  def bell_order_line(notice)
    path = case notice.kind
    when :order_served then card_season_path(slug: notice.edition.id, number: notice.edition.season_number)
    when :order_expired then market_my_orders_path
    else market_listing_path(token: notice.listing_token)
    end
    sentence = t("shell.bell.market.#{notice.kind}_html", card: notice.card, amount: render(PicoinAmountComponent.new(amount: notice.amount.to_i)))
    BellLine.new(key: "order:#{notice.token}:#{notice.noticed_at.utc.iso8601(6)}", path:, href: path, sentence:, action: t("shell.bell.see"))
  end

  def bell_wanted_line(wanted)
    BellLine.new(key: "#{Game::BellRead::GROUPED_WANTED_KEY}:#{wanted.newest_at.utc.iso8601(6)}", path: nil, href: market_path(wanted: "1"),
      sentence: t("shell.bell.market.wanted_grouped", count: wanted.count, card: wanted.card), action: t("shell.bell.see"), read: wanted.seen)
  end

  def bell_reaction_subject(subject)
    if subject.set then SetLabel.for(subject.set)
    elsif subject.card && subject.partner_card then t("shell.bell.reaction_trade", card: subject.card, partner_card: subject.partner_card)
    else subject.card
    end
  end

  def bell_daily_line(day)
    path = hotwire_native_app? ? home_path : booster_path
    BellLine.new(key: "daily:#{day.iso8601}", path:, href: path,
      sentence: t("shell.bell.daily"), action: t("shell.bell.collect"), lasting: true, dom_id: "bell-daily")
  end

  def bell_goal_line(goal)
    href = home_path(anchor: "community-goal")
    if goal.reward_ready
      BellLine.new(key: "mission-reward:#{goal.week_start.iso8601}", path: nil, href:,
        sentence: t("shell.bell.mission_reward"), action: t("shell.bell.collect"), lasting: true, dom_id: "bell-mission-reward")
    else
      sentence = t(goal.reached ? "shell.bell.mission_reached" : "shell.bell.mission", target: number_with_delimiter(goal.target))
      BellLine.new(key: "mission:#{goal.week_start.iso8601}", path: nil, href:, sentence:, action: t("shell.bell.see"))
    end
  end
end
