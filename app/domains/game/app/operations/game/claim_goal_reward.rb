module Game
  # Claims a player's weekly goal reward, named by its week: one reward pack
  # of Pack::SIZE cards, at least one an Épique or better (Game::RewardDraw),
  # drawn now from the current season and available now. Like the daily
  # bonus, it is refused while the reserve is full. Under the bank lock, with
  # `now` taken once:
  #
  # 1. the player earned no reward that week: Failure(:reward_not_earned);
  # 2. the reward already has its pack: Failure(:reward_already_claimed);
  # 3. no published season: Failure(:reward_no_season), and the reward waits;
  # 4. the reserve (Game::Reserve, the query the page reads) holds
  #    Game::Reserve::FULL packs: Failure(:reward_reserve_full), and the
  #    reward waits;
  # 5. the reward pack is inserted and linked to the reward, and
  #    Game::GoalRewardClaimed is published.
  #
  # The lock serialises a player's claims, so a reward gets one pack however
  # often it is claimed. A nil week (a date that does not parse) is a reward
  # not earned.
  #
  #   Game::ClaimGoalReward.new.call(player:, week_start: Date)
  #   # => Success(pack) | Failure(:player_required) | Failure(:reward_not_earned) | Failure(:reward_already_claimed)
  #   #    | Failure(:reward_no_season) | Failure(:reward_reserve_full)
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
        step room_in_reserve(player, now)
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

    def room_in_reserve(player, now)
      Reserve.full?(Reserve.count(player.id, now:)) ? Failure(:reward_reserve_full) : Success()
    end
  end
end
