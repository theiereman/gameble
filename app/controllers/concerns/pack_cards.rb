# An opened pack's cards for a controller that shows them: the pack's page,
# the opening exchange and the booster showing an opened pack again.
module PackCards
  extend ActiveSupport::Concern

  private
    # The pack's cards as Catalog::CardViews in the request's locale, in
    # drawn order, a card drawn twice there twice.
    def cards_of(pack)
      views = Catalog::CardViews.call(pack.card_season_ids, locale: I18n.locale)
      pack.card_season_ids.map { |id| views.fetch(id) }
    end
end
