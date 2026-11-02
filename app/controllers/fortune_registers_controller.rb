class FortuneRegistersController < ApplicationController
  include FortunePeriod

  def show
    authorize :page, :show?
    @period = fortune_period(params[:period])
    @board = Game::FortuneBoard.call(current_player, period: @period)
  end
end
