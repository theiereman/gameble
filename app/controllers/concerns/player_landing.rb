module PlayerLanding
  extend ActiveSupport::Concern

  HUB_PATH = %r{\A/(?<locale>#{I18n.available_locales.join("|")})/?\z}

  private
    def landing_path_for(player, origin = nil)
      return origin unless origin.nil? || HUB_PATH.match?(origin)

      locale = origin ? HUB_PATH.match(origin)[:locale] : I18n.locale
      player.welcome_pending ? home_path(locale:) : booster_path(locale:)
    end
end
