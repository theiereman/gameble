# Claiming a weekly goal reward from the hub's goal panel, named by its week:
# the reward booster joins the reserve. From the hub the claim answers in
# Turbo Stream, which replaces the claim slot, the packs chip, menu 01, the
# empty showcase's action and, once the reserve is full, the daily booster
# panel, and adds a toast; without JavaScript it redirects to the hub. A
# refusal answers the same way, with the slot as the server shows it.
class GoalRewardsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("goal_rewards.create.throttled"), status: :see_other }

  # POST /:locale/goal-rewards/:week
  def create
    authorize :goal_reward, :create?

    result = Game::ClaimGoalReward.new.call(player: current_player, week_start: week)
    tone = result.success? ? :notice : :alert
    message = result.success? ? t("goal_rewards.create.collected") : Game::ClaimGoalReward.failure_message(result.failure)

    respond_to do |format|
      format.turbo_stream do
        @bank = Game::BankSummary.call(current_player)
        @reward = Game::GoalRewardStatus.call(current_player)
        @message = message
        @tone = tone
      end
      format.html { redirect_to home_path, tone => message, status: :see_other }
    end
  end

  private
    def week
      Date.iso8601(params[:week])
    rescue Date::Error
      nil
    end
end
