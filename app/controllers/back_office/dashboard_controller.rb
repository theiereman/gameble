module BackOffice
  # The staff back-office (R9). An empty shell for now: moderation arrives
  # with epic 2, the catalog import with epic 7.
  class DashboardController < ApplicationController
    def show
      authorize [ :back_office, :dashboard ], :show?
    end
  end
end
