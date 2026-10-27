module Game
  class GrantGoalRewardsJob < ActiveJob::Base
    queue_as :default

    BATCH_SIZE = 500

    def perform(week_start:)
      return unless WeeklyGoal.reached.exists?(week_start:)

      granted = GoalReward.where(week_start:).select(:player_id)
      WeeklyContribution.where(week_start:).where.not(player_id: granted).in_batches(of: BATCH_SIZE) do |batch|
        Accounts::Player.where(id: batch.select(:player_id), banned_at: nil, deleted_at: nil).order(:id).each do |player|
          GrantGoalReward.new.call(player:, week_start:)
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id, week_start: })
        end
      end
    end
  end
end
