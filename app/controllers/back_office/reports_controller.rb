module BackOffice
  class ReportsController < ApplicationController
    def index
      authorize [ :back_office, :reports ], :index?
      @reports_by_player = Accounts::ReportQueue.call(viewer: current_player).group_by(&:reported)
      @banned_players = Accounts::BannedPlayers.call
    end
  end
end
