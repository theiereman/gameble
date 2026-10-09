module BackOffice
  # The staff back-office: the size of the queue of reported players, and
  # links to the pages the staff member's role opens.
  class DashboardController < BaseController
    def show
      authorize [ :back_office, :dashboard ], :show?
      @queue_size = Accounts::ReportQueue.size
    end
  end
end
