class FeedTypeSheetsController < ApplicationController
  layout "sheet"

  def show
    authorize :page, :show?
    @filter = params[:filter].presence_in(FeedsController::FILTERS.keys)
    @tab = params[:tab].presence_in(FeedsController::TABS) if current_player
  end
end
