module Game
  module ExportOf
    HeldCard = Data.define(:card_season_id, :quantity, :last_gained_at)
    PackRow = Data.define(:token, :kind, :season_number, :card_back, :available_at, :opened_at, :card_season_ids)
    Contribution = Data.define(:week_start, :openings)
    ReachedTier = Data.define(:season_number, :kind, :key, :tier, :reached_by, :reached_at)
    Discovery = Data.define(:card_season_id, :discovered_at)
    SetRef = Data.define(:season_number, :kind, :key)
    Entry = Data.define(:kind, :card_season_id, :occurred_at, :set, :tier, :set_count) do
      def initialize(kind:, card_season_id:, occurred_at:, set: nil, tier: nil, set_count: nil) = super
    end
    Unlock = Data.define(:achievement, :unlocked_at)
    Line = Data.define(:card_season_id, :quantity)
    TradeRow = Data.define(:status, :proposed_at, :closed_at, :offered)
    Invitations = Data.define(:received, :sent)

    Result = Data.define(:friend_code, :held_cards, :packs, :daily_bonus_days, :goal_reward_weeks, :contributions,
      :set_tiers, :discoveries, :feed_entries, :unlocks, :friend_count, :invitations, :trades) do
      def card_season_ids
        (held_cards.map(&:card_season_id) + packs.flat_map(&:card_season_ids) + discoveries.map(&:card_season_id) +
          feed_entries.filter_map(&:card_season_id) + trades.flat_map { |trade| trade.offered.map(&:card_season_id) }).uniq
      end
    end

    def self.call(player, now: Time.current)
      invitations = InvitationsOf.call(player)
      Result.new(
        friend_code: FriendCodeOf.call(player),
        held_cards: held_cards(player),
        packs: packs(player),
        daily_bonus_days: DailyBonusClaim.where(player_id: player.id).order(:day).pluck(:day),
        goal_reward_weeks: GoalReward.where(player_id: player.id).order(:week_start).pluck(:week_start),
        contributions: WeeklyContribution.where(player_id: player.id).order(:week_start)
          .pluck(:week_start, :openings).map { |week_start, openings| Contribution.new(week_start:, openings:) },
        set_tiers: set_tiers(player),
        discoveries: FirstDiscovery.where(player_id: player.id).order(:discovered_at, :card_season_id)
          .pluck(:card_season_id, :discovered_at).map { |id, at| Discovery.new(card_season_id: id, discovered_at: at) },
        feed_entries: feed_entries(player),
        unlocks: AchievementUnlock.where(player_id: player.id).order(:unlocked_at, :achievement)
          .pluck(:achievement, :unlocked_at).map { |achievement, unlocked_at| Unlock.new(achievement:, unlocked_at:) },
        friend_count: FriendsOf.call(player).size,
        invitations: Invitations.new(received: invitations.received.size, sent: invitations.sent.size),
        trades: trades(player, now)
      )
    end

    def self.held_cards(player)
      Holding.where(player_id: player.id).where(Holding.arel_table[:quantity].gt(0)).order(:card_season_id)
        .pluck(:card_season_id, :quantity, :last_gained_at)
        .map { |id, quantity, last_gained_at| HeldCard.new(card_season_id: id, quantity:, last_gained_at:) }
    end

    def self.packs(player)
      rows = Pack.where(player_id: player.id).order(:available_at, :id)
        .pluck(:token, :kind, :season_id, :card_back, :available_at, :opened_at, :card_season_ids)
      numbers = Catalog::Season.where(id: rows.map { it[2] }.uniq).pluck(:id, :number).to_h
      rows.map do |token, kind, season_id, card_back, available_at, opened_at, card_season_ids|
        unopened = opened_at.nil?
        PackRow.new(token:, kind:, season_number: numbers[season_id], available_at:, opened_at:,
          card_back: unopened ? nil : card_back || CardBacks::STANDARD,
          card_season_ids: unopened ? [] : card_season_ids)
      end
    end

    def self.set_tiers(player)
      tiers = SetTier.where(player_id: player.id).order(:reached_at, :set_id, :id).pluck(:set_id, :tier, :reached_by, :reached_at)
      sets = set_refs(tiers.map(&:first))
      tiers.filter_map do |set_id, tier, reached_by, reached_at|
        set = sets[set_id]
        ReachedTier.new(season_number: set.season_number, kind: set.kind, key: set.key, tier:, reached_by:, reached_at:) if set
      end
    end

    def self.feed_entries(player)
      rows = FeedEntry.where(player_id: player.id).or(FeedEntry.where(partner_id: player.id)).order(:occurred_at, :id)
        .pluck(:kind, :player_id, :card_season_id, :partner_card_season_id, :occurred_at, :set_id, :tier, :set_count)
      sets = set_refs(rows.filter_map { it[5] })
      rows.map do |kind, player_id, card_season_id, partner_card_season_id, occurred_at, set_id, tier, set_count|
        if set_id
          Entry.new(kind:, card_season_id: nil, occurred_at:, set: sets[set_id], tier:, set_count:)
        else
          Entry.new(kind:, card_season_id: player_id == player.id ? card_season_id : partner_card_season_id, occurred_at:)
        end
      end
    end

    def self.set_refs(set_ids)
      return {} if set_ids.empty?

      Catalog::Set.where(id: set_ids.uniq).joins(:season).pluck(:id, "catalog_seasons.number", :kind, :key)
        .to_h { |id, season_number, kind, key| [ id, SetRef.new(season_number:, kind:, key:) ] }
    end

    def self.trades(player, now)
      trades = Trade.where(proposer_id: player.id).or(Trade.where(recipient_id: player.id)).order(:proposed_at, :id).to_a
      items = TradeItem.where(trade_id: trades.map(&:id)).order(:card_season_id).group_by(&:trade_id)
      trades.map do |trade|
        side = trade.proposer_id == player.id ? "offer" : "request"
        offered = items.fetch(trade.id, []).select { it.side == side }
          .map { Line.new(card_season_id: it.card_season_id, quantity: it.quantity) }
        status = trade.open? && trade.expired?(now) ? "expired" : trade.status
        TradeRow.new(status:, proposed_at: trade.proposed_at, closed_at: trade.closed_at, offered:)
      end
    end

    private_class_method :held_cards, :packs, :set_tiers, :feed_entries, :set_refs, :trades
  end
end
