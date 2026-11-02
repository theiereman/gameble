class FortuneRegistersController < ApplicationController
  include Pagy::Method
  include FortunePeriod

  MAX_PAGE = 10_000

  def show
    authorize :page, :show?
    @period = fortune_period(params[:period])
    @sort = params[:sort] == "capsules" ? :capsules : :luck
    @pagy, fortunes = pagy(:offset, Game::FortuneBoard.ranked(@period, sort: @sort), limit: Game::FortuneBoard::PAGE_SIZE,
      page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    @rows = Game::FortuneBoard.rows(fortunes.to_a)
    @summary = Game::FortuneBoard.summary(@period)
    @mine = Game::FortuneStanding.call(current_player, period: @period) if current_player
    @cards = Catalog::CardViews.call(@rows.select { it.shown_to?(current_player) }.flat_map(&:showcase_ids), locale: I18n.locale)
  end
end
