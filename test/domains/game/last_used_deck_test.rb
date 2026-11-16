require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

class Game::LastUsedDeckTest < ActiveSupport::TestCase
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    @first = complete_deck(@lea, "Lea")
    @second = complete_deck(@lea, "Max")
    complete_deck(@hugo, "Hugo")
  end

  def challenge(deck) = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck.token).value!

  test "a player who never seated a deck has no last used deck" do
    assert_nil Game::LastUsedDeck.call(@lea)
  end

  test "the last used deck is the one of the player's latest seat holding a deck" do
    Game::CancelChallenge.new.call(player: @lea, token: challenge(@first).token).value!
    assert_equal @first.token, Game::LastUsedDeck.call(@lea)

    Game::CancelChallenge.new.call(player: @lea, token: challenge(@second).token).value!
    assert_equal @second.token, Game::LastUsedDeck.call(@lea)
  end

  test "a seat without a deck, such as an invitation, does not count" do
    duel = challenge(@first)

    assert_nil Game::LastUsedDeck.call(@hugo)
    Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: 0).value!
    assert_equal deck_token_of(@hugo), Game::LastUsedDeck.call(@hugo)
  end
end
