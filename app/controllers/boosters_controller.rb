class BoostersController < ApplicationController
  include PackCards
  include SeasonAllocationGate
  include GoalMarksLoading

  before_action :lead_to_season_allocation, only: :show

  def show
    authorize :booster, :show?
    @bank = Game::BankSummary.call(current_player)
    @reserve = initial_reserve
    @next_pack_size = Game::NextPackSize.call(current_player)
    respond_to do |format|
      format.html do
        @season = Catalog::PublishedSeason.call
        @opened_pack = Game::OpenedPackByToken.call(current_player, params[:pack])
        @opened_cards = @opened_pack && cards_of(@opened_pack)
        @opened_first_copies = @opened_pack ? Game::FirstCopies.call(current_player, @opened_pack) : []
        @opened_goals = @opened_pack ? goal_marks : GoalMarks::NONE
        @next_steps = Game::NextSteps.call(current_player, season: @season) if reserve_run_out?
      end
      format.json { render json: { bank: helpers.booster_bank(bank: @bank, next_pack_size: @next_pack_size) } }
    end
  end

  private

  def reserve_run_out?
    @bank[:available].zero? && @bank[:special].zero? && @opened_pack.nil?
  end

  def initial_reserve
    return "special" if @bank[:available].zero? && @bank[:special].positive?

    Game::Reserve.of(params[:reserve]) == "special" && @bank[:special].positive? ? "special" : "standard"
  end
end
