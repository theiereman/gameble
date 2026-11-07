class AchievementClaimsController < ApplicationController
  throttle_player to: 10, only: :create, path: -> { achievements_path }, alert: "achievement_claims.create.throttled"

  def create
    authorize :achievement_claim, :create?

    result = Game::ClaimAchievement.new.call(player: current_player, achievement: params[:achievement].to_s)
    tone = result.success? ? :notice : :alert
    message = result.success? ? t("achievement_claims.create.claimed") : Game::ClaimAchievement.failure_message(result.failure)

    respond_to do |format|
      format.turbo_stream do
        @tile = Game::AchievementBoard.call(current_player).find { it.key.to_s == params[:achievement].to_s }
        @unclaimed = Game::UnclaimedAchievements.count(current_player)
        @message = message
        @tone = tone
      end
      format.html { redirect_to achievements_path, tone => message, status: :see_other }
    end
  end
end
