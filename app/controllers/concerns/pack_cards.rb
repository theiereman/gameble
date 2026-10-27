module PackCards
  extend ActiveSupport::Concern

  private
    def cards_of(pack)
      views = Catalog::CardViews.call(pack.card_season_ids, locale: I18n.locale)
      pack.card_season_ids.map { |id| views.fetch(id) }
    end
end
