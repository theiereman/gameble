class DeckFillsController < ApplicationController
  include DeckChanges

  limit_deck_changes only: :create

  def create
    deck = owned_deck(:update?)
    result = Game::FillDeckGaps.new.call(player: current_player, token: params[:token])
    answer_change(result, Game::FillDeckGaps) do |filled|
      refs = deck_refs(filled.placed.map(&:last))
      { slots: filled.placed.map { |slot, card_season_id| { slot:, ref: refs[card_season_id] } }, count: filled.count,
        coverage: helpers.deck_coverage_json(Game::DeckCoverage.new(current_player, deck)) }
    end
  end

  private
    def deck_refs(card_season_ids)
      Catalog::CardViews.call(card_season_ids, locale: I18n.locale)
        .transform_values { Game::Market::EntrustableCopies.ref(it.id, it.season_number) }
    end
end
