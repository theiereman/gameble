module Game
  class AddCardToDeck < Operation
    include DeckSteps

    def call(player:, token:, card_season_id:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        deck = step locked_deck(player, token)
        cards = locked_cards(deck)
        present = cards.find { it.card_season_id == card_season_id }
        next Placed.new(slot: present.slot, count: cards.size) if present

        elsewhere = decked_elsewhere(player, deck, [ card_season_id ]).include?(card_season_id)
        holding = lock_holdings(player, [ card_season_id ])[card_season_id]
        step owned(holding)
        step ranked(card_season_id)
        card_id = Catalog::CardSeason.where(id: card_season_id).pick(:card_id)
        step game_not_in(cards, card_id)
        step room_in(cards)
        step free_copy(holding, elsewhere)
        slot = (Deck::SLOTS.to_a - cards.map(&:slot)).first
        DeckCard.create!(deck_id: deck.id, card_season_id:, card_id:, slot:)
        reserve_copy(player, card_season_id) unless elsewhere
        step deck_published(DeckCardAdded, player, deck, card_season_id:)
        Placed.new(slot:, count: cards.size + 1)
      end
    end
  end
end
