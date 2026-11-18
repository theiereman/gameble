class DecksController < ApplicationController
  require_feature :duels
  include DeckChanges

  limit_deck_changes only: %i[create update]
  throttle_player to: 60, only: :destroy, path: -> { new_deck_path }, alert: "decks.throttled"

  def new
    authorize :deck, :new?, policy_class: DeckPolicy
    @room_left = Game::PlayerDecks.room_left?(current_player)
    @editor = DeckEditor.new(current_player, deck: nil, locale: I18n.locale) if @room_left
  end

  def show
    deck = owned_deck(:show?)
    @editor = DeckEditor.new(current_player, deck:, locale: I18n.locale)
  end

  def create
    authorize :deck, :create?, policy_class: DeckPolicy
    result = Game::CreateDeck.new.call(player: current_player, name: params[:name])
    answer_change(result, Game::CreateDeck) do |deck|
      { token: deck.token, url: deck_path(token: deck.token), name: deck.name }
    end
  end

  def update
    owned_deck(:update?)
    result = Game::RenameDeck.new.call(player: current_player, token: params[:token], name: params[:name])
    answer_change(result, Game::RenameDeck) { |deck| { name: deck.name } }
  end

  def destroy
    owned_deck(:destroy?)
    result = Game::DeleteDeck.new.call(player: current_player, token: params[:token])
    return redirect_refused(Game::DeleteDeck, result, new_deck_path) if result.failure?

    flash[:notice] = t("decks.deleted")
    flash[:deck_deleted] = true
    redirect_to duels_path, status: :see_other
  end
end
