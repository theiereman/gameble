class SessionsController < ApplicationController
  # Set in the session by the request phase (config/initializers/omniauth.rb)
  # and consumed by the callback: a callback this browser did not start is
  # refused (login CSRF).
  SIGN_IN_STARTED = "steam_sign_in_started".freeze

  # Steam's return is a browser GET that rack-openid relabels as POST, so it
  # carries no authenticity token. Login CSRF is guarded by SIGN_IN_STARTED.
  skip_forgery_protection only: :create
  # OmniAuth's test mode sends the callback as a real GET, and signing in writes.
  skip_around_action :read_only_unless_writing, only: :create

  ORIGIN_PATH = %r{\A/(?:#{I18n.available_locales.join("|")})(?:/[^\\\s]*)?\z}
  INVITE_PATH = %r{\A/(?:#{I18n.available_locales.join("|")})/invite/[1-9A-HJ-NP-Za-km-z]{24}\z}

  # GET /auth/steam/callback, after OmniAuth has verified the response.
  def create
    authorize :session
    return fail_sign_in("errors.steam.sign_in_failed") unless session.delete(SIGN_IN_STARTED)

    result = Steam::SignInIdentity.steam_id_from(request.env["omniauth.auth"])
    return fail_sign_in(Steam::SignInIdentity.failure_key(result.failure)) if result.failure?

    steam_id = result.value!
    result = sign_in(steam_id)
    return fail_sign_in(Accounts::SignIn.failure_key(:sign_in_failed)) if result.nil?
    return refuse_banned(steam_id) if result.failure == :banned
    return fail_sign_in(Accounts::SignIn.failure_key(result.failure)) if result.failure?

    player = result.value!
    reset_session
    session[:player_id] = player.id
    if (invite = invite_origin)
      redirect_to invite, notice: t(".welcome")
    else
      redirect_to home_path, notice: (t(".welcome") unless player.welcome_pending), flash: { signed_in: true }
    end
  end

  # GET /auth/failure: Steam refused, the visitor cancelled, or the response
  # did not verify.
  def failure
    authorize :session
    session.delete(SIGN_IN_STARTED)
    fail_sign_in("errors.steam.sign_in_failed")
  end

  # DELETE /session
  def destroy
    authorize :session
    # The landing keeps the player's motion preference (the cookie).
    write_motion_cookie(current_player.reduced_motion)
    reset_session
    redirect_to landing_path, notice: t(".farewell")
  end

  private
    # The result of Accounts::SignIn, or nil when it raised: a handler of the
    # sign-up (the bank fill, Game::Handlers::PlayerRegistered) that raises
    # rolls the new player back. The error is reported.
    def sign_in(steam_id)
      Accounts::SignIn.new.call(steam_id:, persona_name: persona_name(steam_id))
    rescue StandardError => error
      Rails.error.report(error)
      nil
    end

    # The player's Steam persona name, or nil when Steam fails or is slow (a
    # warning in the log), when the Steam key is missing or rejected, or when
    # anything else goes wrong (both reported); either way the sign-in goes on
    # and the stored name is kept.
    def persona_name(steam_id)
      Steam::WebApi.new.get_player_summary(steamid: steam_id)
    rescue Steam::WebApi::BrokenKey => error
      Rails.error.report(error)
      nil
    rescue Steam::WebApi::Error => error
      Rails.logger.warn("Steam persona name not read at sign-in: #{error.message}")
      nil
    rescue StandardError => error
      Rails.error.report(error)
      nil
    end

    def fail_sign_in(key)
      redirect_to return_path, alert: t(key)
    end

    def refuse_banned(steam_id)
      @ban_reason = Accounts::CurrentBanReason.call(steam_id)
      render :banned, status: :forbidden
    end

    # The callback and the failure carry no locale segment: the locale is the
    # one of the origin page, else the default one.
    def requested_locale
      params[:locale] || origin_path&.split("/")&.at(1)
    end

    def invite_origin
      origin = origin_path
      origin if origin && INVITE_PATH.match?(origin)
    end

    def return_path
      origin_path || landing_path
    end

    # The origin, only when it is a local path (one leading "/", no host)
    # whose first segment is a locale; anything else is ignored.
    def origin_path
      origin = request.env["omniauth.origin"] || params[:origin]
      return nil unless origin.is_a?(String)

      path = origin.split(/[?#]/, 2).first
      path if ORIGIN_PATH.match?(path)
    end
end
