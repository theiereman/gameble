class FortunePanelsController < ApplicationController
  ALL_TIME_TAB = "all_time"

  def show
    authorize :page, :play?
    @panel = Game::FortunePanel.call(current_player, tab: params[:tab] == ALL_TIME_TAB ? :all_time : :week)
  end
end
