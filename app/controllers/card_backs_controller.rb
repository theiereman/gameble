class CardBacksController < ApplicationController
  def update
    authorize :card_back, :update?
    result = Game::ChooseCardBack.new.call(player: current_player, back: params[:back].to_s, season: params[:season].presence)

    if result.success?
      announce(result.value!)
      redirect_to personalization_path, status: :see_other
    else
      back_refused(Game::ChooseCardBack.failure_message(result.failure), code: result.failure.to_s)
    end
  end

  private
    def announce(back)
      flash[:chosen_back] = back.key
      flash[:toast_title] = t("card_backs.chosen.title")
      flash[:notice] = t("card_backs.chosen.text", name: helpers.card_back_name(back))
    end

    def back_refused(message, code:)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("toasts", ToastComponent.new(message:, tone: :alert)), status: :unprocessable_content }
        format.html { redirect_to personalization_path, alert: message, status: :see_other }
        format.json { render json: { error: { code:, message: } }, status: :unprocessable_content }
      end
    end
end
