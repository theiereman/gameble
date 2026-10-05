# Steam sign-in and sign-out (CAP-1, AD-14). The web layer orchestrates:
# Steam turns the verified OpenID response into a Steam id and reads the
# player's persona name, Accounts signs the player in and stores that name
# (CAP-8), and the session keeps only the player id. The name is a bonus: a
# Steam failure while reading it never blocks the sign-in.
#
# A sign-in returns to the page it started on (OmniAuth's origin) when that
# is a local page under a locale, else to home. Only a successful sign-in
# touches the session; a failed or forged one leaves it as it was.
class SessionsController < ApplicationController
  # Set in the session by the request phase (config/initializers/omniauth.rb)
  # and consumed by the callback: a callback this browser did not start is
  # refused (login CSRF).
  SIGN_IN_STARTED = "steam_sign_in_started".freeze

  # Steam's return is a browser GET that rack-openid relabels as POST, so it
  # carries no authenticity token. Login CSRF is guarded by SIGN_IN_STARTED.
  skip_forgery_protection only: :create
  # The callback signs the player in, which writes (Accounts::SignIn), so it
  # never runs under the read-only role (AD-11). Through Steam it arrives as
  # a POST anyway (rack-openid relabels the return with `_method=post`); it
  # is a real GET only under OmniAuth's test mode, which is what this skip
  # covers. `failure` and `destroy` keep the role.
  skip_around_action :read_only_unless_writing, only: :create

  ORIGIN_PATH = %r{\A/(?:#{I18n.available_locales.join("|")})(?:/[^\\\s]*)?\z}

  # GET /auth/steam/callback, after OmniAuth has verified the response.
  def create
    authorize :session
    return fail_sign_in("errors.steam.sign_in_failed") unless session.delete(SIGN_IN_STARTED)

    result = Steam::SignInIdentity.steam_id_from(request.env["omniauth.auth"])
    return fail_sign_in(Steam::SignInIdentity.failure_key(result.failure)) if result.failure?

    result = sign_in(result.value!)
    return fail_sign_in(Accounts::SignIn.failure_key(:sign_in_failed)) if result.nil?
    return fail_sign_in(Accounts::SignIn.failure_key(result.failure)) if result.failure?

    reset_session
    session[:player_id] = result.value!.id
    redirect_to return_path, notice: t(".welcome")
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
    reset_session
    redirect_to home_path, notice: t(".farewell")
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

    # The player's Steam persona name, or nil when Steam fails (a warning in
    # the log) or anything else goes wrong (reported); either way the
    # sign-in goes on and the stored name is kept.
    def persona_name(steam_id)
      Steam::WebApi.new.get_player_summary(steamid: steam_id)
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

    # The callback and the failure carry no locale segment: the locale is the
    # one of the origin page, else the default one.
    def requested_locale
      params[:locale] || origin_path&.split("/")&.at(1)
    end

    def return_path
      origin_path || home_path
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
