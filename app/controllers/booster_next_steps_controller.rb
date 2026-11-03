class BoosterNextStepsController < ApplicationController
  def show
    authorize :booster, :next_steps?
    return redirect_to booster_path unless turbo_frame_request?

    @bank = Game::BankSummary.call(current_player)
    @next_steps = Game::NextSteps.call(current_player, season: Catalog::PublishedSeason.call)
  end
end
