class AchievementClaimsController < ApplicationController
  throttle_player to: 10, only: :create, path: -> { achievements_path }, alert: "achievement_claims.create.throttled"

  def create
    authorize :achievement_claim, :create?

    result = Game::ClaimAchievement.new.call(player: current_player, achievement: params[:achievement].to_s)
    if result.success?
      redirect_to achievements_path, notice: t("achievement_claims.create.claimed"), status: :see_other
    else
      redirect_to achievements_path, alert: Game::ClaimAchievement.failure_message(result.failure), status: :see_other
    end
  end
end
