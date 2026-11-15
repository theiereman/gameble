# Frees a deck-blocked copy from the trade, sale and entrust screens: the edition leaves every deck, and the screen reloads.
class DeckRemovalsController < ApplicationController
  throttle_player to: 60, only: :create, path: -> { new_deck_path }, alert: "decks.removal.throttled"

  def create
    authorize :deck, :remove_card?, policy_class: DeckPolicy
    ref = params[:ref].to_s
    card_season_id = Game::Market::EntrustableCopies.resolve([ ref ])[ref]
    return refused(:card_not_owned) if card_season_id.nil?

    result = Game::RemoveFromDecks.new.call(player: current_player, card_season_id:)
    return refused(result.failure) if result.failure?

    card = Game::Market::CardNames.call([ card_season_id ])[card_season_id]&.title
    redirect_back_or_to new_deck_path, notice: t("decks.removal.done", card:), status: :see_other
  end

  private
    def refused(code)
      redirect_back_or_to new_deck_path, alert: Game::RemoveFromDecks.failure_message(code), status: :see_other
    end
end
