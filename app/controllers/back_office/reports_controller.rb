module BackOffice
  class ReportsController < ApplicationController
    include Pagy::Method

    PAGE_SIZE = 50
    MAX_PAGE = 100_000

    rate_limit to: 30, within: 1.minute, only: :dismiss

    def index
      authorize [ :back_office, :reports ], :index?
      @pagy, players = pagy(:offset, Accounts::ReportQueue.players, limit: PAGE_SIZE, page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
      @rows = Accounts::ReportQueue.rows(players)
    end

    def dismiss
      authorize [ :back_office, :reports ], :dismiss?

      player = Accounts::PlayerByToken.call(params[:token])
      result = Accounts::DismissReports.new.call(staff: current_player, player:)
      if result.success?
        redirect_to back_office_reports_path, notice: t(".dismissed", name: helpers.public_profile_title(player)), status: :see_other
      else
        redirect_to back_office_reports_path, alert: Accounts::DismissReports.failure_message(result.failure), status: :see_other
      end
    end
  end
end
