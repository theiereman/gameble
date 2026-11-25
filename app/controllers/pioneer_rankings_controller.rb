class PioneerRankingsController < ApplicationController
  include PublicRead
  include Pagy::Method

  MAX_PAGE = 10_000

  def show
    authorize :page, :show?
    @scope = params[:seasons] == "current" ? :current : :all
    @choice = params[:period] == "season" ? :season : :week
    @period = Game::PioneerBoard.period_for(@choice, @scope)
    now = Time.current
    @pagy, standings = pagy(:offset, Game::PioneerBoard.ranked(@period, now:), limit: Game::PioneerBoard::PAGE_SIZE,
      page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    @rows = Game::PioneerBoard.rows(standings.to_a)
    @supporters = Game::SupporterStatus.for_players(@rows.map(&:player))
    @place = Game::PioneerBoard.place(current_player, @period, now:) if current_player
    @friends = Game::FriendsOf.call(current_player).to_set(&:id)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
