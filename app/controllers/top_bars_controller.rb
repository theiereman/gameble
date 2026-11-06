class TopBarsController < ApplicationController
  def show
    authorize :top_bar, :show?
    @bank = Game::BankSummary.reserve(current_player)

    respond_to do |format|
      format.turbo_stream
    end
  end
end
