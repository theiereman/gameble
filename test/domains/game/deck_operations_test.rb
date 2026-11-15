require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/decks"

# Creating, renaming and deleting a player's decks: five at most, a name of 1 to 24 characters unique to the player
# whatever its case; each change writes one event, a refusal or a change already made writes nothing.
class Game::DeckOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include Decks

  setup do
    @player = accounts_players(:player)
  end

  def create(name: nil, player: @player) = Game::CreateDeck.new.call(player:, name:)

  def rename(token, name, player: @player) = Game::RenameDeck.new.call(player:, token:, name:)

  def delete(token, player: @player) = Game::DeleteDeck.new.call(player:, token:)

  def add(token, card_season_id, player: @player) = Game::AddCardToDeck.new.call(player:, token:, card_season_id:)

  def writes = Game::Deck.count + Game::DeckCard.count + Rails.configuration.event_store.read.count

  def assert_refused(code, &operation)
    assert_no_difference -> { writes } do
      assert_equal code, operation.call.failure
    end
  end

  test "a deck with no name is named Deck and the lowest number its player does not use, with one event" do
    first = create.value!
    create(name: "deck 3").value!

    assert_equal [ "Deck 1", @player.id ], [ first.name, first.player_id ]
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, first.token)
    assert_equal "Deck 2", create(name: "  ").value!.name
    assert_equal "Deck 4", create.value!.name
    assert_equal [ { player_id: @player.id, deck_id: first.id } ], game_events(@player, Game::DeckCreated).first(1).map(&:data)
  end

  test "a name is cleaned as a set's is, and refused empty, over 24 characters or used by another deck of the player" do
    assert_equal "Vieux briscards", create(name: " Vieux  briscards​ ").value!.name
    assert create(name: "é" * 24).success?

    assert_refused(:deck_name_too_long) { create(name: "a" * 25) }
    assert_refused(:deck_name_taken) { create(name: "VIEUX BRISCARDS") }
    assert_refused(:deck_name_required) { create(name: 42) }
    assert create(name: "Vieux briscards", player: accounts_players(:moderator)).success?
  end

  test "a sixth deck is refused" do
    5.times { create.value! }

    assert_refused(:too_many_decks) { create }
  end

  test "a rename writes the new name and one event; the same name writes nothing; a refused name leaves the saved one" do
    deck = create(name: "Vieux").value!
    other = create(name: "Confidentiels").value!

    assert_no_difference -> { writes } do
      assert_equal "Vieux", rename(deck.token, " Vieux ").value!.name
    end
    assert_equal "vieux", rename(deck.token, "vieux").value!.name
    assert_equal [ { player_id: @player.id, deck_id: deck.id } ], game_events(@player, Game::DeckRenamed).map(&:data)
    assert_refused(:deck_name_required) { rename(deck.token, "") }
    assert_refused(:deck_name_too_long) { rename(deck.token, "a" * 25) }
    assert_refused(:deck_name_taken) { rename(deck.token, "CONFIDENTIELS") }
    assert_refused(:deck_not_found) { rename(other.token, "Autre", player: accounts_players(:moderator)) }
    assert_equal "vieux", deck.reload.name
  end

  test "a deletion drops the deck and its cards, frees only the copies no other deck holds, and writes one event" do
    alone, shared, last = ranked_cards(@player, 3)
    deck = create.value!
    other = create.value!
    [ alone, shared, last ].each { add(deck.token, it).value! }
    add(other.token, shared).value!

    assert_equal deck.name, delete(deck.token).value!

    assert_not Game::Deck.exists?(deck.id)
    assert_equal [ shared ], Game::DeckCard.pluck(:card_season_id)
    assert_equal [ 0, 1, 0 ], [ alone, shared, last ].map { reserved_of(@player, it) }
    assert_equal [ { player_id: @player.id, deck_id: deck.id } ], game_events(@player, Game::DeckDeleted).map(&:data)
  end

  test "another player's deck, or a token that is no string, is not found" do
    deck = create.value!

    assert_refused(:deck_not_found) { delete(deck.token, player: accounts_players(:moderator)) }
    assert_refused(:deck_not_found) { delete([ deck.token ]) }
  end

  test "no player, an unsaved, a banned or a deleted one is refused by every operation" do
    token = create.value!.token
    card_season_id = catalog_card_seasons(:portal_one).id
    deleted = accounts_players(:moderator)
    deleted.update_columns(deleted_at: Time.current, steam_id: nil)

    [ nil, Accounts::Player.new, accounts_players(:banned), deleted ].each do |player|
      assert_refused(:player_required) { create(player:) }
      assert_refused(:player_required) { rename(token, "Autre", player:) }
      assert_refused(:player_required) { add(token, card_season_id, player:) }
      assert_refused(:player_required) { Game::RemoveCardFromDeck.new.call(player:, token:, card_season_id:) }
      assert_refused(:player_required) { delete(token, player:) }
    end
  end
end
