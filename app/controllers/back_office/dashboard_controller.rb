module BackOffice
  class DashboardController < BaseController
    def show
      authorize [ :back_office, :dashboard ], :show?
      @queue_size = Accounts::ReportQueue.size
    end
  end
end
