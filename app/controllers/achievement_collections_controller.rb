class AchievementCollectionsController < ApplicationController
  def create
    authorize :achievement, :collect?

    result = Game::CollectAchievement.new.call(player: current_player, achievement: params[:key])
    if result.success?
      flash[:toast_title] = t("achievement_collections.collected.title")
      flash[:notice] = t("achievements.names.#{result.value!.key}")
    else
      flash[:alert] = Game::CollectAchievement.failure_message(result.failure)
    end
    redirect_to achievements_path, status: :see_other
  end
end
