class DuelsController < ApplicationController
  def show
    authorize :duel, :show?
    @decks = DeckList.new(current_player, locale: I18n.locale)
    @lobby = DuelLobby.new(current_player, decks: @decks, friend_token: params[:friend])
    @landing = flash[:deck_deleted] ? "" : nil
  end

  def play
    duel = authorize(Game::DuelByToken.call(params[:token]) || :duel, :play?, policy_class: DuelPolicy)
    @screen = DuelScreen.new(duel, duel.seat_of(current_player), locale: I18n.locale)
  end
end
