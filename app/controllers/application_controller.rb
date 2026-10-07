class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Pages meant to be read from a shared link (the PublicRead concern's
  # public_read?) are open to any browser, so link previews (Discord, X,
  # WhatsApp) and older browsers get them.
  allow_browser versions: :modern, unless: :public_read?

  # First, so everything the request reads (the player included) runs on
  # the role it chose.
  around_action :read_only_unless_writing
  around_action :switch_locale
  before_action :set_sentry_user
  before_action :note_presence

  # Every action takes a policy decision (AD-14); one that skipped `authorize`
  # raises Pundit::AuthorizationNotPerformedError.
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :refuse

  # The motion preference's cookie (EXPERIENCE.md, Reduced motion; AD-27):
  # the player's "Animations réduites" setting mirrored for the visitor they
  # become at sign-out. "reduced" forces reduced motion, "full" is an
  # explicit "no"; no cookie follows the system.
  MOTION_COOKIE = :motion
  MOTION_COOKIE_VALUES = { "reduced" => true, "full" => false }.freeze

  # The session's mark of the last time a request enqueued the player's
  # last-seen write (CAP-21, AD-24), in epoch seconds.
  PRESENCE_MARK = :seen_at

  helper_method :current_player, :motion_reduced?

  private
    # Whether this request reads a page meant to be opened from a shared
    # link, by any browser or link-preview crawler. None by default; the
    # PublicRead concern opens a controller's GET and HEAD requests.
    def public_read?
      false
    end

    # A GET or HEAD reads (AD-11): it runs under the `reading` role with
    # writes prevented, so a write from an ApplicationRecord model or the
    # event store raises ActiveRecord::ReadOnlyError. A write a page needs
    # is a separate POST to an operation. Enqueuing a job is not a write to
    # the primary: Solid Queue keeps its own connection class.
    def read_only_unless_writing(&action)
      if request.get? || request.head?
        ApplicationRecord.connected_to(role: :reading, prevent_writes: true, &action)
      else
        yield
      end
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
    # player, or one whose account was deleted (from another browser too),
    # is signed out and the request goes on as a visitor's. Only the player
    # id leaves the session: a sign-in in progress keeps its marker.
    def current_player
      return @current_player if defined?(@current_player)

      player = Accounts::PlayerById.call(session[:player_id])
      if player&.banned? || player&.deleted?
        session.delete(:player_id)
        player = nil
      end
      @current_player = player
    end

    # The motion preference: a signed-in player's own setting (nil follows
    # the system), a visitor's cookie. true forces reduced motion.
    def motion_setting
      current_player ? current_player.reduced_motion : MOTION_COOKIE_VALUES[cookies[MOTION_COOKIE]]
    end

    # Whether the server forces reduced motion: the layout sets
    # `html[data-motion=reduced]` from it and drops the view-transition meta
    # (AD-27). The system's own preference is read by CSS and motion.ts.
    def motion_reduced?
      motion_setting == true
    end

    # Mirrors a setting (true, false, nil) in the motion cookie, which lives
    # a year; nil removes it.
    def write_motion_cookie(setting)
      if setting.nil?
        cookies.delete(MOTION_COOKIE)
      else
        cookies[MOTION_COOKIE] = { value: setting ? "reduced" : "full", expires: 1.year.from_now, httponly: true, same_site: :lax }
      end
    end

    # Errors reported to Sentry carry the player id, and nothing else about
    # the player (AD-21). Sentry runs only where SENTRY_DSN is set.
    def set_sentry_user
      Sentry.set_user(id: current_player.id) if Sentry.initialized? && current_player
    end

    # Notes that the signed-in player was seen: enqueues
    # Accounts::NoteLastSeenJob with the request's time, at most once per
    # Accounts::NoteLastSeen::THROTTLE for the session, and not when the
    # account already shows a time that recent. Enqueuing is not a write
    # (AD-11): a GET stays read only. The mark lives in the session cookie.
    def note_presence
      return unless current_player

      now = Time.current
      throttle = Accounts::NoteLastSeen::THROTTLE
      return if session[PRESENCE_MARK].to_i > (now - throttle).to_i
      return if current_player.last_seen_at && current_player.last_seen_at > now - throttle

      Accounts::NoteLastSeenJob.perform_later(current_player.id, now)
      session[PRESENCE_MARK] = now.to_i
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
