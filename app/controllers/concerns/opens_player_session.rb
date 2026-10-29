module OpensPlayerSession
  extend ActiveSupport::Concern

  CLERK_SESSION_COOKIE = "__session".freeze

  private
    def carry_visitor_motion_switch(player)
      return player unless cookies[ApplicationController::MOTION_COOKIE] == ApplicationController::FORCED_MOTIONS.key(true)

      Accounts::UpdateSettings.new.call(player:, reduced_motion: true).value_or(player)
    end

    def open_session_for(player)
      player = carry_visitor_motion_switch(player)
      reset_session
      session[:player_id] = player.id
      player
    end

    def safe_origin_path(origin)
      return nil unless origin.is_a?(String)

      path = origin.split(/[?#]/, 2).first
      path if SessionsController::ORIGIN_PATH.match?(path)
    end

    def invite_target(origin)
      origin if origin && SessionsController::INVITE_PATH.match?(origin)
    end

    def redirect_signed_in(player, origin)
      if (invite = invite_target(origin))
        redirect_to invite, notice: t("sessions.create.welcome"), status: :see_other
      else
        redirect_to origin || home_path, notice: (t("sessions.create.welcome") unless player.welcome_pending), flash: { signed_in: true }, status: :see_other
      end
    end

    def clerk_session_token
      cookies[CLERK_SESSION_COOKIE].to_s
    end
end
