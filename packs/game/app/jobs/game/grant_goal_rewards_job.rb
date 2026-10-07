module Game
  # Rewards the contributors of a reached weekly goal (CAP-12, AD-9, AD-14;
  # story 6.5): every player with a contribution that week and no reward yet
  # gets one through Game::GrantGoalReward, in their own transaction. Enqueued
  # by Game::SumWeeklyGoalJob each time a reached goal's total moves, so a
  # player who contributes after the goal was reached is rewarded on the next
  # sum. A rerun grants nothing twice; banned players and refusals are
  # skipped; a player whose grant raises is reported and the others are
  # still served.
  class GrantGoalRewardsJob < ActiveJob::Base
    queue_as :default

    BATCH_SIZE = 500

    def perform(week_start:)
      return unless WeeklyGoal.reached.exists?(week_start:)

      granted = GoalReward.where(week_start:).select(:player_id)
      WeeklyContribution.where(week_start:).where.not(player_id: granted).in_batches(of: BATCH_SIZE) do |batch|
        Accounts::Player.where(id: batch.select(:player_id), banned_at: nil).order(:id).each do |player|
          GrantGoalReward.new.call(player:, week_start:)
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id, week_start: })
        end
      end
    end
  end
end
