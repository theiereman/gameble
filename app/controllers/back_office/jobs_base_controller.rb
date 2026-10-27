module BackOffice
  class JobsBaseController < BaseController
    before_action :authorize_jobs
    before_action :nonce_inline_scripts

    helper MissionControl::Jobs::HostRouteHelpers

    private
      def authorize_jobs
        authorize [ :back_office, :jobs ], :show?
      end

      def nonce_inline_scripts
        request.content_security_policy_nonce_directives = %w[script-src style-src]
      end
  end
end
