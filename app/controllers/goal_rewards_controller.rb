class GoalRewardsController < ApplicationController
  throttle_player to: 5, only: :create, path: -> { home_path }, alert: "goal_rewards.create.throttled"

  def create
    authorize :goal_reward, :create?

    result = Game::ClaimGoalReward.new.call(player: current_player, week_start: week)
    tone = result.success? ? :notice : :alert
    message = result.success? ? t("goal_rewards.create.collected") : Game::ClaimGoalReward.failure_message(result.failure)
    title = t("goal_rewards.create.title") if result.success?

    respond_to do |format|
      format.turbo_stream do
        @bank = Game::BankSummary.call(current_player)
        @reward = Game::GoalRewardStatus.call(current_player)
        @message = message
        @title = title
        @tone = tone
      end
      format.html do
        flash[:toast_title] = title if title
        redirect_to home_path, tone => message, status: :see_other
      end
    end
  end

  private
    def week
      Date.iso8601(params[:week])
    rescue Date::Error
      nil
    end
end
