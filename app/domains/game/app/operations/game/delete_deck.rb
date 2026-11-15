module Game
  class DeleteDeck < Operation
    include DeckSteps

    def call(player:, token:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        deck = step locked_deck(player, token)
        editions = locked_cards(deck).map(&:card_season_id)
        alone = editions - decked_elsewhere(player, deck, editions).to_a
        lock_holdings(player, editions)
        release_copies(player, alone)
        Deck.where(id: deck.id).delete_all
        step deck_published(DeckDeleted, player, deck)
        deck.name
      end
    end
  end
end
