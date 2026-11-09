class FortuneRegistersController < ApplicationController
  include PublicRead
  include Pagy::Method
  include FortunePeriod

  MAX_PAGE = 10_000

  def show
    authorize :page, :show?
    @period = register_period(params[:period])
    @sort = params[:sort] == "capsules" ? :capsules : :luck
    now = Time.current
    @pagy, fortunes = pagy(:offset, Game::FortuneBoard.ranked(@period, now:, sort: @sort), limit: Game::FortuneBoard::PAGE_SIZE,
      page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    @summary = Game::FortuneBoard.summary(@period, now:)
    @rows = Game::FortuneBoard.rows(fortunes.to_a, ranked_count: @summary.ranked_count, viewer: current_player, now:)
    @mine = Game::FortuneStanding.call(current_player, period: @period, now:) if current_player
    @privileged_floor = Game::Privileged.floor_index(now:) if @period == :week
    @privileged_cut = @period == :week && @sort == :luck
    @distribution = Game::FortuneDistribution.call(@period, now:)
  end
end
