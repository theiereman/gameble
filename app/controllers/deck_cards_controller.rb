class DeckCardsController < ApplicationController
  include DeckChanges

  limit_deck_changes only: %i[create destroy]

  def create
    change(Game::AddCardToDeck)
  end

  def destroy
    change(Game::RemoveCardFromDeck)
  end

  private
    def change(operation)
      deck = owned_deck(:update?)
      ref = params[:ref].to_s
      card_season_id = Game::Market::EntrustableCopies.resolve([ ref ])[ref]
      return refuse_change(:card_not_owned, operation.failure_message(:card_not_owned)) if card_season_id.nil?

      result = operation.new.call(player: current_player, token: params[:token], card_season_id:)
      answer_change(result, operation) do |placed|
        { slot: placed.slot, count: placed.count, coverage: helpers.deck_coverage_json(Game::DeckCoverage.new(deck)) }
      end
    end
end
