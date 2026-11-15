class DuelsController < ApplicationController
  def show
    authorize :duel, :show?
    @decks = DeckList.new(current_player, locale: I18n.locale)
    @landing = flash[:deck_deleted] ? "" : nil
  end
end
