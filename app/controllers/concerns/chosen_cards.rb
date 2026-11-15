module ChosenCards
  extend ActiveSupport::Concern

  private
    def chosen_cards(player) = card_views_in_order(Game::ChosenShowcase.call(player))

    def chosen_and_stage_cards(player)
      chosen = Game::ChosenShowcase.call(player)
      stage = chosen + Game::BestCards.call(player, limit: Game::ChosenShowcase::SIZE - chosen.size, except: chosen)
      views = stage.empty? ? {} : Catalog::CardViews.call(stage, locale: I18n.locale)
      [ chosen.filter_map { views[it] }, stage.filter_map { views[it] } ]
    end

    def card_views_in_order(ids)
      return [] if ids.empty?

      views = Catalog::CardViews.call(ids, locale: I18n.locale)
      ids.filter_map { views[it] }
    end
end
