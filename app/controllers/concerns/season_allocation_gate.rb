module SeasonAllocationGate
  extend ActiveSupport::Concern

  private
    def lead_to_season_allocation
      return unless current_player && page_navigation?

      redirect_to season_allocation_path if Game::SeasonAllocationPending.call(current_player)
    end

    def page_navigation?
      request.get? && request.format == Mime[:html] && !turbo_frame_request?
    end
end
