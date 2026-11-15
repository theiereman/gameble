# The player's decked editions on the sale and entrust screens: the decks naming each cell, by ref, and the views their
# removal dialogs draw.
module DeckHoldingLoading
  extend ActiveSupport::Concern

  private
    def load_deck_holding
      @deck_names = current_player ? Game::DecksHolding.call(current_player) : {}
      @deck_views = Catalog::CardViews.call(@deck_names.keys, locale: I18n.locale)
      @decks_by_ref = @deck_views.to_h { |id, view| [ Game::Market::EntrustableCopies.ref(view.id, view.season_number), @deck_names.fetch(id) ] }
    end
end
