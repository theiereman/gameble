module BackOffice
  class BaseController < ApplicationController
    prepend_before_action :hide_from_non_staff

    private
      def hide_from_non_staff
        return if read_only_unless_writing { current_player&.staff? }

        raise ActionController::RoutingError, "No route matches [#{request.request_method}] #{request.path.inspect}"
      end
  end
end
