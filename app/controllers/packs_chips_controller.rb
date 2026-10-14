class PacksChipsController < ApplicationController
  def show
    authorize :packs_chip, :show?
    @bank = Game::BankSummary.reserve(current_player)

    respond_to do |format|
      format.turbo_stream
    end
  end
end
