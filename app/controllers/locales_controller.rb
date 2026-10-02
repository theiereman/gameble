# Sends "/" to the locale that best matches the browser, else the default one.
class LocalesController < ApplicationController
  def redirect
    locale = http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale
    redirect_to home_path(locale: locale)
  end
end
