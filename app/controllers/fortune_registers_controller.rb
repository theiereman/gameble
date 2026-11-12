class FortuneRegistersController < ApplicationController
  include PublicRead
  include Pagy::Method

  MAX_PAGE = 10_000

  def show
    authorize :page, :show?
    @sort = params[:sort] == "capsules" ? :capsules : :luck
    now = Time.current
    @pagy, fortunes = pagy(:offset, Game::FortuneBoard.ranked(now:, sort: @sort), limit: Game::FortuneBoard::PAGE_SIZE,
      page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    @summary = Game::FortuneBoard.summary(now:)
    @rows = Game::FortuneBoard.rows(fortunes.to_a, ranked_count: @summary.ranked_count, viewer: current_player, now:)
    @mine = Game::FortuneStanding.call(current_player, period: :week, now:) if current_player
    @privileged_floor = Game::Privileged.floor_index(now:)
    @privileged_cut = @sort == :luck
    @distribution = Game::FortuneDistribution.call(now:)
  end
end
