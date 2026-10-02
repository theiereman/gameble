# Steam sign-in and sign-out (CAP-1, AD-14). The web layer orchestrates:
# Steam turns the verified OpenID response into a Steam id, Accounts signs
# the player in, and the session keeps only the player id.
#
# A sign-in returns to the page it started on (OmniAuth's origin) when that
# is a local page under a locale, else to home. Only a successful sign-in
# touches the session; a failed or forged one leaves it as it was.
class SessionsController < ApplicationController
  # Set in the session by the request phase (config/initializers/omniauth.rb)
  # and consumed by the callback: a callback this browser did not start is
  # refused (login CSRF).
  SIGN_IN_STARTED = "steam_sign_in_started".freeze

  ORIGIN_PATH = %r{\A/(?:#{I18n.available_locales.join("|")})(?:/[^\\\s]*)?\z}

  # GET /auth/steam/callback, after OmniAuth has verified the response.
  def create
    return fail_sign_in("errors.steam.sign_in_failed") unless session.delete(SIGN_IN_STARTED)

    result = Steam::SignInIdentity.steam_id_from(request.env["omniauth.auth"])
    return fail_sign_in(Steam::SignInIdentity.failure_key(result.failure)) if result.failure?

    result = Accounts::SignIn.new.call(steam_id: result.value!)
    return fail_sign_in(Accounts::SignIn.failure_key(result.failure)) if result.failure?

    reset_session
    session[:player_id] = result.value!.id
    redirect_to return_path, notice: t(".welcome")
  end

  # GET /auth/failure: Steam refused, the visitor cancelled, or the response
  # did not verify.
  def failure
    session.delete(SIGN_IN_STARTED)
    fail_sign_in("errors.steam.sign_in_failed")
  end

  # DELETE /session
  def destroy
    reset_session
    redirect_to home_path, notice: t(".farewell")
  end

  private
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
