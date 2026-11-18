module Game
  module BellItems
    PER_KIND = 5

    TradeLine = Data.define(:token, :player, :revision)
    InvitationLine = Data.define(:token, :player)
    GoalLine = Data.define(:week_start, :reward_ready, :target, :reached)
    UpdateLine = Data.define(:token, :player, :outcome, :closed_at)
    ReactionLine = Data.define(:token, :name, :others, :count, :noticed_at, :kinds, :subject)
    ReactionSubject = Data.define(:card, :partner_card, :set)
    DuelLine = Data.define(:token, :opponent, :kind, :outcome, :score, :other_score, :ended_at)
    Result = Data.define(:trades, :updates, :invitations, :reactions, :market, :daily, :goal, :duels)
    FINISHED_FOR = 7.days

    def self.call(player, now: Time.current, locale: I18n.locale)
      trades = trades_waiting(player, now).to_a
      updates = TradeUpdates.call(player, now:)
      invitations = invitations_waiting(player).to_a
      duels = duel_seats(player, now)
      senders = Accounts::Player.where(id: trades.map(&:proposer_id) | invitations.map(&:sender_id) | updates.map(&:recipient_id) |
        duels.filter_map { |seat| other_seat(seat).player_id }).index_by(&:id)

      Result.new(
        trades: trades.map { TradeLine.new(token: it.token, player: senders[it.proposer_id], revision: it.revision) },
        updates: updates.map { UpdateLine.new(token: it.token, player: senders[it.recipient_id], outcome: it.status, closed_at: it.closed_at) },
        invitations: invitations.map { InvitationLine.new(token: it.token, player: senders[it.sender_id]) },
        reactions: reaction_lines(ReactionUpdates.call(player, now:), locale),
        market: Market::MarketNotices.call(player:, locale:),
        daily: daily(player, now),
        goal: goal(player, now),
        duels: duels.map { duel_line(it, senders) }
      )
    end

    def self.duel_seats(player, now)
      resuming = DuelInProgress.call(player)
      finished = DuelSeat.joins(:duel).includes(duel: :seats).where(player_id: player.id, game_duels: { state: "finished", practice: false })
        .where(game_duels: { ended_at: (now - FINISHED_FOR).. }).order("game_duels.ended_at DESC").limit(PER_KIND)
      [ *resuming, *finished ]
    end
    private_class_method :duel_seats

    def self.other_seat(seat) = seat.duel.seats.find { it.role != seat.role }
    private_class_method :other_seat

    def self.duel_line(seat, senders)
      duel = seat.duel
      scores = duel.state == "finished" ? [ duel.challenger_score, duel.opponent_score ] : [ 0, 0 ]
      scores = scores.reverse if seat.role == "opponent"
      outcome = { seat.role => :win, "draw" => :draw }.fetch(duel.result, :loss) if duel.state == "finished"
      DuelLine.new(token: duel.token, opponent: senders[other_seat(seat).player_id], kind: duel.state == "finished" ? :finished : :resume,
        outcome:, score: scores.first, other_score: scores.last, ended_at: duel.ended_at)
    end
    private_class_method :duel_line

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

    def self.reaction_lines(updates, locale)
      entries = updates.map(&:entry)
      cards = Catalog::CardViews.call(entries.flat_map { [ it.card_season_id, it.partner_card_season_id ] }.compact, locale:)
      sets = Catalog::SetsById.call(entries.filter_map(&:set_id))
      updates.map do |update|
        entry = update.entry
        subject = ReactionSubject.new(card: cards[entry.card_season_id]&.title, partner_card: cards[entry.partner_card_season_id]&.title,
          set: sets[entry.set_id])
        ReactionLine.new(token: entry.token, name: update.name, others: update.name ? update.reactors - 1 : 0, count: update.reactors,
          noticed_at: update.noticed_at, kinds: update.kinds, subject:)
      end
    end
    private_class_method :reaction_lines

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
