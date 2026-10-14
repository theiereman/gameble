class AchievementsController < ApplicationController
  def show
    authorize :achievement, :show?
    @tiles = Game::AchievementBoard.call(current_player)
  end
end
