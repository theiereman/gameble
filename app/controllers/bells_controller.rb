class BellsController < ApplicationController
  def show
    authorize :bell, :show?
    return redirect_to(home_path, status: :see_other) unless turbo_frame_request?

    @items = Game::BellItems.call(current_player)
  end
end
