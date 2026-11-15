module Game
  class CreateDeck < Operation
    include DeckSteps

    DEFAULT_NAME = "Deck %d".freeze

    def call(player:, name: nil)
      player = step require_player(player)
      name = step chosen_name(name)

      transaction do
        step lock_bank(player)
        step room_left(player)
        name ||= default_name(player)
        step deck_name_free(player, name)
        deck = Deck.create!(player_id: player.id, name:)
        step deck_published(DeckCreated, player, deck)
        deck
      end
    end

    private

    def chosen_name(name)
      return Success(nil) if name.nil? || (name.is_a?(String) && VisibleName.call(name).empty?)

      clean_deck_name(name)
    end

    def room_left(player)
      Deck.where(player_id: player.id).count < Deck::PER_PLAYER ? Success() : Failure(:too_many_decks)
    end

    def default_name(player)
      used = Deck.where(player_id: player.id).pluck(Arel.sql("lower(name)")).to_set
      format(DEFAULT_NAME, (1..).find { !used.include?(format(DEFAULT_NAME, it).downcase) })
    end
  end
end
