module Game
  class FillDeckGaps < Operation
    include DeckSteps

    Filled = Data.define(:placed, :count)

    def call(player:, token:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        deck = step locked_deck(player, token)
        cards = locked_cards(deck)
        room = Deck::SLOTS.size - cards.size
        picks = room.positive? ? DeckCoverage.new(player, deck, card_season_ids: cards.map(&:card_season_id)).fill(room:) : []
        next Filled.new(placed: [], count: cards.size) if picks.empty?

        elsewhere = decked_elsewhere(player, deck, picks)
        holdings = lock_holdings(player, picks)
        added = step placeable(deck, cards, picks, holdings, elsewhere)
        added.each(&:save!)
        shift_reserved(player, picks.reject { elsewhere.include?(it) }, +1)
        step deck_published(DeckGapsFilled, player, deck, card_season_ids: picks)
        Filled.new(placed: added.map { [ it.slot, it.card_season_id ] }, count: cards.size + added.size)
      end
    end

    private

    def placeable(deck, cards, picks, holdings, elsewhere)
      free_slots = Deck::SLOTS.to_a - cards.map(&:slot)
      card_ids = Catalog::CardSeason.where(id: picks).pluck(:id, :card_id).to_h
      placed = cards.dup
      picks.each do |card_season_id|
        holding = holdings[card_season_id]
        step owned(holding)
        step ranked(card_season_id)
        step game_not_in(placed, card_ids[card_season_id])
        step room_in(placed)
        step free_copy(holding, elsewhere.include?(card_season_id))
        placed << DeckCard.new(deck_id: deck.id, card_season_id:, card_id: card_ids[card_season_id], slot: free_slots.shift)
      end
      Success(placed.drop(cards.size))
    end
  end
end
