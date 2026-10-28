module SeasonAllocationGate
  extend ActiveSupport::Concern

  private
    def lead_to_season_allocation
      return unless current_player && request.get? && request.format == Mime[:html]

      redirect_to season_allocation_path if Game::SeasonAllocationPending.call(current_player)
    end
end
