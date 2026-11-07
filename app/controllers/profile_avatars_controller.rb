class ProfileAvatarsController < ApplicationController
  include PersonalizationRefusal

  def update
    authorize :profile_avatar, :update?
    result = Game::ChooseAvatar.new.call(player: current_player, avatar: params[:avatar].to_s)

    if result.success?
      flash[:chosen_avatar] = "yes"
      flash[:toast_title] = t("profile_avatars.chosen.title")
      flash[:notice] = t("profile_avatars.chosen.text", name: t("avatars.names.#{result.value!.key}"))
      refresh_or_redirect_to me_path, status: :see_other
    else
      personalization_refused(Game::ChooseAvatar.failure_message(result.failure), code: result.failure.to_s)
    end
  end
end
