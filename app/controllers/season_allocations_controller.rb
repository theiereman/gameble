class SeasonAllocationsController < ApplicationController
  throttle_player to: 30, only: :create, path: -> { season_allocation_path }, alert: "season_allocations.create.throttled"

  def show
    authorize :season_allocation, :show?
    return redirect_to(home_path) unless Game::SeasonAllocationPending.call(current_player)

    @recap = Game::SeasonAllocationRecap.call(current_player)
  end

  def create
    authorize :season_allocation, :create?

    if Game::MarkAllocationSeen.new.call(player: current_player).success?
      redirect_to home_path, status: :see_other
    else
      redirect_to season_allocation_path, alert: t("season_allocations.create.failed"), status: :see_other
    end
  end
end
