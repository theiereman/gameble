module ChosenCards
  extend ActiveSupport::Concern

  private
    def chosen_cards(player)
      ids = Game::ChosenShowcase.call(player)
      return [] if ids.empty?

      views = Catalog::CardViews.call(ids, locale: I18n.locale)
      ids.filter_map { views[it] }
    end
end
