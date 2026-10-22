# Sends "/" to the locale that best matches the browser, else the default
# one: to the hub for a player, to the landing for a visitor.
class LocalesController < ApplicationController
  def redirect
    authorize :page, :show?
    locale = http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale
    keep_out_of_shared_caches
    redirect_to home_path(locale:)
  end

  private
    # Cloudflare's cache ignores Vary, so a stored redirect would send everyone to one language.
    def keep_out_of_shared_caches
      response.cache_control.replace(private: true, no_store: true)
      response.headers["Vary"] = [ response.headers["Vary"], "Accept-Language" ].compact_blank.join(", ")
    end
end
