module Game
  class RenameDeck < Operation
    include DeckSteps

    def call(player:, token:, name:)
      player = step require_player(player)
      name = step clean_deck_name(name)

      transaction do
        step lock_bank(player)
        deck = step locked_deck(player, token)
        next deck if deck.name == name

        step deck_name_free(player, name, except: deck)
        deck.update!(name:)
        step deck_published(DeckRenamed, player, deck)
        deck
      end
    end
  end
end
