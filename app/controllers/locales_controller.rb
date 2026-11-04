class LocalesController < ApplicationController
  def redirect
    authorize :page, :show?
    locale = http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale
    keep_out_of_shared_caches
    redirect_to home_path(locale:)
  end

  private
    def keep_out_of_shared_caches
      # Cloudflare ignores Vary, so a cached redirect would send everyone to one language.
      response.cache_control.replace(private: true, no_store: true)
      response.headers["Vary"] = [ response.headers["Vary"], "Accept-Language" ].compact_blank.join(", ")
    end
end
