# The cards a player chose for their profile showcase, for a controller
# that shows them: the public profile and the settings' profile summary.
module ChosenCards
  extend ActiveSupport::Concern

  private
    # The player's chosen cards as Catalog::CardViews in the request's
    # locale, in their order; none costs one query.
    def chosen_cards(player)
      ids = Game::ChosenShowcase.call(player)
      return [] if ids.empty?

      views = Catalog::CardViews.call(ids, locale: I18n.locale)
      ids.filter_map { views[it] }
    end
end
