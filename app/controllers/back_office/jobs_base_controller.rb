module BackOffice
  # Base controller of Mission Control Jobs (config/initializers/mission_control.rb).
  # Every engine action passes here first: administrators only. A visitor is
  # sent home to sign in, any other player gets 403, through
  # ApplicationController's refusal path.
  class JobsBaseController < ApplicationController
    before_action :authorize_jobs

    # A refusal renders the app's layout inside the engine, whose views see
    # only the engine's routes: the app's route helpers are delegated to
    # main_app, as Mission Control already does for its controllers.
    helper MissionControl::Jobs::HostRouteHelpers

    private
      def authorize_jobs
        authorize [ :back_office, :jobs ], :show?
      end
  end
end
