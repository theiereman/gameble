module Game
  module SeasonAllocationRecap
    TierReached = Data.define(:tier, :set)
    AchievementEarned = Data.define(:key, :unlocked_at) do
      def earned = true
    end
    Recap = Data.define(:season_number, :ended_season_number, :earned, :achievements, :backs, :received)

    SETS_OF_SEASON = "JOIN catalog_sets ON catalog_sets.id = game_set_tiers.set_id " \
      "JOIN catalog_seasons ON catalog_seasons.id = catalog_sets.season_id".freeze

    def self.call(player)
      published = Catalog::PublishedSeason.call
      state = PlayerState.find_by(player_id: player.id)
      ended_number = published.number - 1
      ended = Catalog::Season.find_by(number: ended_number)

      Recap.new(season_number: published.number, ended_season_number: ended_number,
        earned: earned_tiers(player, ended_number), achievements: achievements(player, ended, published),
        backs: CardBacksEarnedIn.call(player, ended, before: published.published_at), received: received_tiers(player, published, state))
    end

    def self.earned_tiers(player, ended_number)
      rows = SetTier.where(player_id: player.id, reached_by: %w[pack trade]).joins(SETS_OF_SEASON)
        .where(catalog_seasons: { number: ended_number }).order(:reached_at, :id).pluck(:set_id, :tier)
      tiers_reached(rows)
    end
    private_class_method :earned_tiers

    def self.received_tiers(player, published, state)
      rows = if received_season(state) >= published.number
        SetTier.where(player_id: player.id, reached_by: "allocation").joins(SETS_OF_SEASON)
          .where(catalog_sets: { season_id: published.id }).order(:id).pluck(:set_id, :tier)
      else
        SetTier.carried(player_id: player.id, season_id: published.id)
      end
      tiers_reached(rows)
    end
    private_class_method :received_tiers

    def self.received_season(state)
      state ? state.allocation_received_season.to_i : 0
    end
    private_class_method :received_season

    def self.achievements(player, ended, published)
      unlocks = AchievementUnlock.where(player_id: player.id, achievement: Achievements::BY_KEY.keys)
      unlocks = unlocks.where(unlocked_at: ended.published_at..) if ended&.published_at
      unlocks = unlocks.where(unlocked_at: ...published.published_at) if published.published_at
      unlocks.order(:unlocked_at, :achievement).pluck(:achievement, :unlocked_at).map { |key, at| AchievementEarned.new(key: key.to_sym, unlocked_at: at) }
    end
    private_class_method :achievements

    def self.tiers_reached(rows)
      sets = Catalog::SetsById.call(rows.map(&:first))
      rows.map { |set_id, tier| TierReached.new(tier:, set: sets.fetch(set_id)) }
    end
    private_class_method :tiers_reached
  end
end
