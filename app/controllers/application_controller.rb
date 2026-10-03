class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Pages meant to be read from a shared link (public_read?) are open to any
  # browser, so link previews (Discord, X, WhatsApp) and older browsers get them.
  allow_browser versions: :modern, unless: :public_read?

  around_action :switch_locale
  before_action :set_sentry_user

  # Every action takes a policy decision (AD-14); one that skipped `authorize`
  # raises Pundit::AuthorizationNotPerformedError.
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :refuse

  helper_method :current_player

  private
    # Whether this request reads a page meant to be opened from a shared
    # link, by any browser or link-preview crawler. None by default.
    def public_read?
      false
    end

    # Each request runs in the locale of its URL (AD-18), Pagy's links
    # included: its locale is per thread, so it is set on every request.
    def switch_locale(&action)
      locale = current_locale
      Pagy::I18n.locale = locale
      I18n.with_locale(locale, &action)
    end

    def current_locale
      locale = requested_locale
      locale.is_a?(String) && I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale
    end

    def requested_locale
      params[:locale]
    end

    # The signed-in player, reloaded on each request from the player id the
    # encrypted session cookie holds (AD-14); nil when signed out. A banned
    # player is signed out and the request goes on as a visitor's. Only the
    # player id leaves the session: a sign-in in progress keeps its marker.
    def current_player
      return @current_player if defined?(@current_player)

      player = Accounts::PlayerById.call(session[:player_id])
      if player&.banned?
        session.delete(:player_id)
        player = nil
      end
      @current_player = player
    end

    # Errors reported to Sentry carry the player id, and nothing else about
    # the player (AD-21). Sentry runs only where SENTRY_DSN is set.
    def set_sentry_user
      Sentry.set_user(id: current_player.id) if Sentry.initialized? && current_player
    end

    def pundit_user
      current_player
    end

    # A refused visitor is sent home and asked to sign in (401 outside HTML);
    # a refused player is forbidden (403). Nothing the action would have done
    # happens. A rescue runs outside the around_action, hence its own locale.
    def refuse
      I18n.with_locale(current_locale) { refuse_in_locale }
    end

    def refuse_in_locale
      if current_player.nil?
        message = t("authorization.sign_in_required")
        refuse_with(:unauthorized, "sign_in_required", message) { redirect_to home_path, alert: message }
      else
        message = t("authorization.forbidden")
        refuse_with(:forbidden, "forbidden", message) do
          render html: helpers.tag.p(message, class: "refusal"), layout: "application", status: :forbidden
        end
      end
    end

    def refuse_with(status, code, message, &html)
      respond_to do |format|
        format.html(&html)
        format.json { render json: { error: { code: code, message: message } }, status: status }
        format.any { head status }
      end
    end

    # Links built with route helpers keep the current locale.
    def default_url_options
      { locale: I18n.locale }
    end
end
