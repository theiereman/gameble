class PlayerExport
  def initialize(player, locale:, now: Time.current)
    @player = player
    @locale = locale
    @now = now
  end

  def exported_at
    @now
  end

  def self.filename(exported_at)
    "gameble-export-#{exported_at.utc.to_date.iso8601}.json"
  end

  def filename
    self.class.filename(@now)
  end

  def to_h
    {
      exportedAt: time(@now),
      profile:,
      collection:,
      showcase:,
      packs:,
      dailyBonusDays: game.daily_bonus_days.map(&:iso8601),
      goalRewardWeeks: game.goal_reward_weeks.map(&:iso8601),
      weeklyContributions: game.contributions.map { { week: it.week_start.iso8601, openings: it.openings } },
      setTiers: game.set_tiers.map do
        { season: it.season_number, kind: it.kind, key: it.key, tier: it.tier, reachedBy: it.reached_by, reachedAt: time(it.reached_at) }
      end,
      firstDiscoveries: game.discoveries.map { { card: card(it.card_season_id), discoveredAt: time(it.discovered_at) } },
      feedEntries: game.feed_entries.map { feed_entry(it) },
      achievements: game.unlocks.map { { achievement: it.achievement, unlockedAt: time(it.unlocked_at) } },
      cardBacks: card_backs,
      friends: { count: game.friend_count },
      pendingInvitations: { received: game.invitations.received, sent: game.invitations.sent },
      trades:,
      reportsFiled: accounts.reports_filed.map { { reason: it.reason, createdAt: time(it.created_at) } },
      reportsReceived: accounts.reports_received.map do
        { reason: it.reason, createdAt: time(it.created_at), handledAt: time(it.handled_at) }
      end,
      moderationDecisions: accounts.decisions.map { { kind: it.kind, createdAt: time(it.created_at), reason: it.reason } }
    }
  end

  private
    def accounts
      @accounts ||= Accounts::ExportOf.call(@player)
    end

    def game
      @game ||= Game::ExportOf.call(@player, now: @now)
    end

    def views
      @views ||= Catalog::CardViews.call(game.card_season_ids, locale: @locale)
    end

    def profile
      profile = accounts.profile
      { steamId: profile.steam_id, personaName: profile.persona_name, visibility: profile.visibility,
        reducedMotion: profile.reduced_motion, friendCode: game.friend_code,
        createdAt: time(profile.created_at), lastSeenAt: time(profile.last_seen_at),
        lastExportedAt: time(profile.last_exported_at) }
    end

    def collection
      game.held_cards.filter_map do |held|
        view = views[held.card_season_id]
        next unless view

        { slug: view.id, season: view.season_number, title: view.title, quantity: held.quantity,
          lastGainedAt: time(held.last_gained_at) }
      end
    end

    def showcase
      game.showcase.filter_map { |entry| card(entry.card_season_id)&.merge(position: entry.position) }
    end

    def packs
      game.packs.map do |pack|
        { token: pack.token, kind: pack.kind, season: pack.season_number, cardBack: pack.card_back, cardBackSeason: pack.card_back_season,
          availableAt: time(pack.available_at), openedAt: time(pack.opened_at),
          cards: pack.card_season_ids.filter_map { card(it) } }
      end
    end

    def card_backs
      { active: game.card_backs.active, activeSeason: game.card_backs.active_season,
        unlocked: game.card_backs.unlocks.map { { back: it.back, unlockedAt: time(it.unlocked_at) } } }
    end

    def trades
      game.trades.map do |trade|
        { status: trade.status, proposedAt: time(trade.proposed_at), closedAt: time(trade.closed_at),
          offered: trade.offered.filter_map { |line| card(line.card_season_id)&.merge(quantity: line.quantity) } }
      end
    end

    def feed_entry(entry)
      if entry.kind == "set"
        set = entry.set && { season: entry.set.season_number, kind: entry.set.kind, key: entry.set.key }
        { kind: entry.kind, set:, tier: entry.tier, count: entry.set_count, occurredAt: time(entry.occurred_at) }
      else
        { kind: entry.kind, card: card(entry.card_season_id), occurredAt: time(entry.occurred_at) }
      end
    end

    def card(card_season_id)
      view = views[card_season_id]
      view && { slug: view.id, season: view.season_number }
    end

    def time(value)
      value&.utc&.iso8601
    end
end
