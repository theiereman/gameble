class ProfileTitlesController < ApplicationController
  include PersonalizationRefusal

  def update
    authorize :profile_title, :update?
    rank, kind, key = params[:title].to_s.split(":", 3)
    result = Game::ChooseProfileTitle.new.call(player: current_player, rank:, kind:, key:)

    if result.success?
      announce(result.value!)
      redirect_to personalization_path, status: :see_other
    else
      personalization_refused(Game::ChooseProfileTitle.failure_message(result.failure), code: result.failure.to_s)
    end
  end

  private
    def announce(title)
      flash[:chosen_title] = "yes"
      if title
        flash[:toast_title] = t("profile_titles.chosen.title")
        flash[:notice] = helpers.profile_title_text(title)
      else
        flash[:toast_title] = t("profile_titles.removed.title")
        flash[:notice] = t("profile_titles.removed.text")
      end
    end
end
