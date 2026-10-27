class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern, unless: :public_read?, block: :refuse_unsupported_browser

  around_action :read_only_unless_writing
  around_action :switch_locale
  before_action :set_sentry_user
  before_action :note_presence

  after_action :verify_authorized
  after_action :keep_out_of_search_engines, unless: -> { Rails.configuration.x.search_indexing }

  rescue_from Pundit::NotAuthorizedError, with: :refuse

  MOTION_COOKIE = :motion
  FORCED_MOTIONS = { "reduced" => true, "full" => false }.freeze

  PRESENCE_MARK = :seen_at

  helper_method :current_player, :forced_motion, :motion_reduced?

  private
    def public_read?
      false
    end

    def keep_out_of_search_engines
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end

    def refuse_unsupported_browser
      render file: ErrorPage.unsupported_browser_file(request), layout: false, status: :not_acceptable
    end

    def read_only_unless_writing(&action)
      if request.get? || request.head?
        ApplicationRecord.connected_to(role: :reading, prevent_writes: true, &action)
      else
        yield
      end
    end

    def switch_locale(&action)
      locale = current_locale
      # Pagy keeps its locale per thread, so it is set on every request.
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

    def current_player
      return @current_player if defined?(@current_player)

      player = Accounts::PlayerById.call(session[:player_id])
      if player&.banned? || player&.deleted?
        session.delete(:player_id)
        player = nil
      end
      @current_player = player
    end

    def motion_setting
      current_player ? current_player.reduced_motion : FORCED_MOTIONS[cookies[MOTION_COOKIE]]
    end

    def forced_motion
      FORCED_MOTIONS.key(motion_setting)
    end

    def motion_reduced?
      forced_motion == "reduced"
    end

    def write_motion_cookie(setting)
      if setting.nil?
        cookies.delete(MOTION_COOKIE)
      else
        cookies[MOTION_COOKIE] = { value: FORCED_MOTIONS.key(setting), expires: 1.year.from_now, httponly: true, same_site: :lax }
      end
    end

    def set_sentry_user
      Sentry.set_user(id: current_player.id) if Sentry.initialized? && current_player
    end

    def note_presence
      return unless current_player

      now = Time.current
      throttle = Accounts::NoteLastSeen::THROTTLE
      return if session[PRESENCE_MARK].to_i > (now - throttle).to_i
      return if current_player.last_seen_at && current_player.last_seen_at > now - throttle

      # Solid Queue writes on its own connection, so enqueueing is not a write under prevent_writes.
      Accounts::NoteLastSeenJob.perform_later(current_player.id, now)
      session[PRESENCE_MARK] = now.to_i
    end

    def pundit_user
      current_player
    end

    def refuse
      # rescue_from runs outside the switch_locale around_action.
      I18n.with_locale(current_locale) { refuse_in_locale }
    end

    def refuse_in_locale
      if current_player.nil?
        message = t("authorization.sign_in_required")
        refuse_with(:unauthorized, "sign_in_required", message) { redirect_to home_path, status: :see_other }
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

    def default_url_options
      { locale: I18n.locale }
    end
end
