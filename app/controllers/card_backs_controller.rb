class CardBacksController < ApplicationController
  include PersonalizationRefusal

  def update
    authorize :card_back, :update?
    result = Game::ChooseCardBack.new.call(player: current_player, back: params[:back].to_s, season: params[:season].presence)

    if result.success?
      equipped(result.value!)
    else
      personalization_refused(Game::ChooseCardBack.failure_message(result.failure), code: result.failure.to_s)
    end
  end

  private
    def equipped(back)
      respond_to do |format|
        format.html do
          flash[:chosen_back] = back.key
          redirect_to personalization_path, status: :see_other
        end
        format.json do
          season = Game::CardBacks.active_with_season(current_player).last
          render json: { back: back.key, season:, announcement: helpers.card_back_equipped(back, season) }
        end
      end
    end
end
