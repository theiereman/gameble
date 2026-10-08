module BackOffice
  class DashboardController < ApplicationController
    def show
      authorize [ :back_office, :dashboard ], :show?
    end
  end
end
