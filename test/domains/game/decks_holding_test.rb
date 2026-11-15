require "test_helper"
require_relative "../../support/decks"

# The decks that hold each of a player's editions, named in the order the player made them; nobody else's decks count.
class Game::DecksHoldingTest < ActiveSupport::TestCase
  include Decks

  setup do
    @player = accounts_players(:player)
  end

  def deck(name, player: @player) = Game::CreateDeck.new.call(player:, name:).value!

  def add(card_season_id, deck, player: @player) = Game::AddCardToDeck.new.call(player:, token: deck.token, card_season_id:).value!

  test "an edition in two decks names both, oldest first; an edition in none is absent" do
    decked, alone, loose = ranked_cards(@player, 3)
    first = deck("Vieux briscards")
    second = deck("Nouveaux venus")
    add(decked, second)
    add(decked, first)
    add(alone, second)

    assert_equal({ decked => [ "Vieux briscards", "Nouveaux venus" ], alone => [ "Nouveaux venus" ] }, Game::DecksHolding.call(@player))
    assert_equal({ alone => [ "Nouveaux venus" ] }, Game::DecksHolding.call(@player, [ alone, loose ]))
  end

  test "another player's decks are never named" do
    card = ranked_cards(@player, 1).sole
    other = accounts_players(:moderator)
    hold(other, card)
    add(card, deck("Leurs cartes", player: other), player: other)

    assert_equal({}, Game::DecksHolding.call(@player))
  end

  test "a visitor or no edition asked costs no query" do
    assert_queries_count(0) do
      assert_equal({}, Game::DecksHolding.call(nil))
      assert_equal({}, Game::DecksHolding.call(@player, []))
    end
  end
end
