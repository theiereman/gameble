require_relative "decks"

# Builds duels in the database through their operations: two friends with a complete deck each, a challenge accepted,
# and rounds played by the moves the rules would play automatically.
module LiveDuels
  include Decks

  LETTERS = ("A".."L").to_a.freeze

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  # Twelve ranked editions held by `player`, titled "<prefix> card A" to "L", in a deck named "<prefix> deck" that
  # reserves its copy of each, as adding them one by one would; the deck.
  def complete_deck(player, prefix)
    ids = ranked_cards(player, 12, titles: LETTERS.map { "#{prefix} card #{it}" })
    deck = Game::CreateDeck.new.call(player:, name: "#{prefix} deck").value!
    ids.each.with_index(1) { |card_season_id, slot| Game::DeckCard.create!(deck:, slot:, card_season_id:, card_id: card_of(card_season_id)) }
    Game::Holding.where(player_id: player.id, card_season_id: ids).update_all(reserved: 1)
    deck
  end

  def deck_token_of(player) = Game::Deck.where(player_id: player.id).order(:created_at, :id).first.token

  # A challenge from `challenger` accepted by `opponent`, each with their first deck; the active duel.
  def start_duel(challenger, opponent)
    duel = Game::ChallengeFriend.new.call(player: challenger, friend: opponent, deck_token: deck_token_of(challenger)).value!
    Game::AcceptChallenge.new.call(player: opponent, token: duel.token, deck_token: deck_token_of(opponent), move_number: duel.move_number)
      .value!
  end

  def rules_of(duel) = Game::DuelRules.new(duel, duel.rounds.to_a)

  def seat_player(duel, role) = Accounts::Player.find(duel.seats.find { it.role == role.to_s }.player_id)

  def position_of(rules, role, card) = rules.deck(role).index(card) + 1

  # Locks the next round's call as the rules would call it automatically; the duel.
  def call_round(duel)
    duel = Game::Duel.find(duel.id)
    rules = rules_of(duel)
    call = rules.automatic_call
    Game::CallRound.new.call(player: seat_player(duel, rules.caller), token: duel.token, move_number: duel.move_number,
      card: position_of(rules, rules.caller, call.card), stat: call.stat, direction: call.direction).value!
  end

  # Answers the locked call as the rules would answer it automatically; the duel.
  def answer_round(duel)
    duel = Game::Duel.find(duel.id)
    rules = rules_of(duel)
    Game::AnswerRound.new.call(player: seat_player(duel, rules.answerer), token: duel.token, move_number: duel.move_number,
      card: position_of(rules, rules.answerer, rules.automatic_answer)).value!
  end

  def play_round(duel) = answer_round(call_round(duel))
end
