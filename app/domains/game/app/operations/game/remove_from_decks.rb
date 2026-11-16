module Game
  class RemoveFromDecks < Operation
    include DeckSteps

    def call(player:, card_season_id:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        decks = locked_decks_holding(player, card_season_id)
        cards = DeckCard.where(deck_id: decks.map(&:id), card_season_id:).order(:id).lock.to_a
        next 0 if cards.empty?

        lock_holdings(player, [ card_season_id ])
        DeckCard.where(id: cards.map(&:id)).delete_all
        release_copies(player, [ card_season_id ])
        deck_ids = cards.map(&:deck_id).uniq.sort
        step publish(CardRemovedFromDecks.new(data: { player_id: player.id, card_season_id:, deck_ids: }), stream_name: stream_name(player.id))
        deck_ids.size
      end
    end

    private

    def locked_decks_holding(player, card_season_id)
      Deck.where(player_id: player.id, id: DeckCard.where(card_season_id:).select(:deck_id)).order(:id).lock.to_a
    end
  end
end
