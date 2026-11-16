class PacksChipsController < ApplicationController
  def show
    authorize :packs_chip, :show?
    @bank = Game::BankSummary.reserve(current_player)
    @reserve = params[:reserve].present?

    respond_to do |format|
      format.turbo_stream
    end
  end
end
