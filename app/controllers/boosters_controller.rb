class BoostersController < ApplicationController
  include PackCards

  def show
    authorize :booster, :show?
    @bank = Game::BankSummary.reserve(current_player)
    @next_pack_size = Game::NextPackSize.call(current_player)
    respond_to do |format|
      format.html do
        @season = Catalog::PublishedSeason.call
        @opened_pack = Game::OpenedPackByToken.call(current_player, params[:pack])
        @opened_cards = @opened_pack && cards_of(@opened_pack)
      end
      format.json { render json: { bank: helpers.booster_bank(bank: @bank, next_pack_size: @next_pack_size) } }
    end
  end
end
