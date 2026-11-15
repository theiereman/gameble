module Game
  class RemoveCardFromDeck < Operation
    include DeckSteps

    def call(player:, token:, card_season_id:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        deck = step locked_deck(player, token)
        cards = locked_cards(deck)
        card = cards.find { it.card_season_id == card_season_id }
        next Placed.new(slot: nil, count: cards.size) if card.nil?

        elsewhere = decked_elsewhere(player, deck, [ card_season_id ]).include?(card_season_id)
        lock_holdings(player, [ card_season_id ])
        DeckCard.where(id: card.id).delete_all
        release_copies(player, [ card_season_id ]) unless elsewhere
        step deck_published(DeckCardRemoved, player, deck, card_season_id:)
        Placed.new(slot: card.slot, count: cards.size - 1)
      end
    end
  end
end
