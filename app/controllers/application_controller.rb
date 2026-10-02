class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale

  helper_method :current_player

  private
    # Each request runs in the locale of its URL (AD-18).
    def switch_locale(&action)
      locale = requested_locale
      locale = I18n.default_locale unless locale.is_a?(String) && I18n.available_locales.map(&:to_s).include?(locale)
      I18n.with_locale(locale, &action)
    end

    def requested_locale
      params[:locale]
    end

    # The signed-in player, reloaded on each request from the player id the
    # encrypted session cookie holds (AD-14); nil when signed out.
    def current_player
      return @current_player if defined?(@current_player)

      @current_player = Accounts::PlayerById.call(session[:player_id])
    end

    # Links built with route helpers keep the current locale.
    def default_url_options
      { locale: I18n.locale }
    end
end
