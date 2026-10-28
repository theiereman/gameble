class ProfileTitlesController < ApplicationController
  def update
    authorize :profile_title, :update?
    rank, kind, key = params[:title].to_s.split(":", 3)
    result = Game::ChooseProfileTitle.new.call(player: current_player, rank:, kind:, key:)

    if result.success?
      announce(result.value!)
      redirect_to personalization_path, status: :see_other
    else
      title_refused(Game::ChooseProfileTitle.failure_message(result.failure), code: result.failure.to_s)
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

    def title_refused(message, code:)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("toasts", ToastComponent.new(message:, tone: :alert)), status: :unprocessable_content }
        format.html { redirect_to personalization_path, alert: message, status: :see_other }
        format.json { render json: { error: { code:, message: } }, status: :unprocessable_content }
      end
    end
end
