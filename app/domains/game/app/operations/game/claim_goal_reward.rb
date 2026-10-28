module Game
  class ClaimGoalReward < Operation
    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:, week_start:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        now = Time.current
        reward = step earned(player, week_start)
        step unclaimed(reward)
        pool = step published_pool
        pack = Pack.create!(Pack.row(player_id: player.id, kind: :reward, season_id: pool.season_id, available_at: now,
          card_season_ids: RewardDraw.cards(pool:, random: @random)))
        reward.update!(pack_id: pack.id)
        step publish(GoalRewardClaimed.new(data: { player_id: player.id, pack_id: pack.id, week_start: week_start.iso8601 }),
          stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def earned(player, week_start)
      reward = week_start && GoalReward.find_by(player_id: player.id, week_start:)
      reward ? Success(reward) : Failure(:reward_not_earned)
    end

    def unclaimed(reward)
      reward.claimed? ? Failure(:reward_already_claimed) : Success()
    end

    def published_pool
      pool = DrawPool.current
      pool ? Success(pool) : Failure(:reward_no_season)
    end
  end
end
