class CardBacksController < ApplicationController
  include PersonalizationRefusal

  def update
    authorize :card_back, :update?
    result = Game::ChooseCardBack.new.call(player: current_player, back: params[:back].to_s, season: params[:season].presence)

    if result.success?
      announce(result.value!)
      redirect_to brother_path(token: current_player.token), status: :see_other
    else
      personalization_refused(Game::ChooseCardBack.failure_message(result.failure), code: result.failure.to_s)
    end
  end

  private
    def announce(back)
      flash[:chosen_back] = back.key
      flash[:toast_title] = t("card_backs.chosen.title")
      flash[:notice] = t("card_backs.chosen.text", name: helpers.card_back_name(back))
    end
end
