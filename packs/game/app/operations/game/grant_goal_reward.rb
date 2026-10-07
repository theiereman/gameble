module Game
  # Grants a contributor the reward of a reached weekly goal (CAP-12, AD-7,
  # AD-9; story 6.5): one reward pack of Pack::SIZE cards, at least one an
  # Épique or better (Game::RewardDraw), available now. It is outside the
  # bank's cap of ten and granted whatever the reserve holds, so it is never
  # lost; it opens like any pack, in arrival order. Under the bank lock, with
  # `now` taken once:
  #
  # 1. the week's goal is not reached: Failure(:goal_not_reached);
  # 2. the player has no contribution that week: Failure(:not_contributor);
  # 3. a reward for that week exists: Failure(:already_granted);
  # 4. no published season: Failure(:no_season), and no reward row, so a
  #    later run grants it;
  # 5. the reward pack is inserted, then the reward row (Game::GoalReward),
  #    and Game::GoalRewardGranted is published.
  #
  # The lock serialises a player's grants; the unique index on (player_id,
  # week_start) is the database's guarantee behind it. Run by
  # Game::GrantGoalRewardsJob, one player per transaction. A player whose
  # account was deleted while it waited on the lock gets nothing
  # (Game::Operation#lock_bank).
  #
  #   Game::GrantGoalReward.new.call(player:, week_start: Date)
  #   # => Success(pack) | Failure(:player_required) | Failure(:goal_not_reached) | Failure(:not_contributor)
  #   #    | Failure(:already_granted) | Failure(:no_season)
  class GrantGoalReward < Operation
    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:, week_start:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        step reached(week_start)
        step contributed(player, week_start)
        step ungranted(player, week_start)
        pool = step published_pool
        pack = Pack.create!(Pack.row(player_id: player.id, kind: :reward, season_id: pool.season_id, available_at: Time.current,
          card_season_ids: RewardDraw.cards(pool:, random: @random)))
        GoalReward.create!(player_id: player.id, week_start:, pack_id: pack.id)
        step publish(GoalRewardGranted.new(data: { player_id: player.id, pack_id: pack.id, week_start: week_start.iso8601 }),
          stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def reached(week_start)
      WeeklyGoal.reached.exists?(week_start:) ? Success() : Failure(:goal_not_reached)
    end

    def contributed(player, week_start)
      WeeklyContribution.exists?(player_id: player.id, week_start:) ? Success() : Failure(:not_contributor)
    end

    def ungranted(player, week_start)
      GoalReward.exists?(player_id: player.id, week_start:) ? Failure(:already_granted) : Success()
    end

    def published_pool
      pool = DrawPool.current
      pool ? Success(pool) : Failure(:no_season)
    end
  end
end
