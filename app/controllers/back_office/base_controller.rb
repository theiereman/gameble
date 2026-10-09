module BackOffice
  # Every back-office page, Mission Control's included. To whoever is not
  # staff (a visitor, a player, a member of staff since banned or deleted)
  # the back-office answers as an unknown address would: the 404 page,
  # before any other callback (the browser check, the forgery check, the
  # rate limit, the policy) can tell it exists. Staff then meet the policies
  # as on any page: a moderator is refused an administrator's page. The
  # player is read on the role the request runs on, as everywhere else.
  class BaseController < ApplicationController
    prepend_before_action :hide_from_non_staff

    private
      def hide_from_non_staff
        return if read_only_unless_writing { current_player&.staff? }

        raise ActionController::RoutingError, "No route matches [#{request.request_method}] #{request.path.inspect}"
      end
  end
end
