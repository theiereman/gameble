require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/decks"

# Freeing a deck-blocked copy: the edition leaves every deck of the player at once, the one copy the decks blocked is
# released, and one event names the decks it left. An edition in no deck writes nothing.
class Game::RemoveFromDecksTest < ActiveSupport::TestCase
  include GamePacks
  include Decks

  setup do
    @player = accounts_players(:player)
    @first = Game::CreateDeck.new.call(player: @player, name: "Vieux briscards").value!
    @second = Game::CreateDeck.new.call(player: @player, name: "Nouveaux venus").value!
  end

  def add(card_season_id, deck) = Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id:).value!

  def free(card_season_id, player: @player) = Game::RemoveFromDecks.new.call(player:, card_season_id:)

  def writes = Game::DeckCard.count + Game::Holding.sum(:reserved) + Rails.configuration.event_store.read.count

  test "an edition in two decks leaves both, frees its one blocked copy and writes one event" do
    card, *others = ranked_cards(@player, 12)
    [ card, *others.first(11) ].each { add(it, @first) }
    add(card, @second)

    assert_equal 2, free(card).value!

    assert_equal 0, Game::DeckCard.where(card_season_id: card).count
    assert_equal 11, Game::DeckSlots.call(@first).size
    assert_equal 0, reserved_of(@player, card)
    assert_equal [ { player_id: @player.id, card_season_id: card, deck_ids: [ @first.id, @second.id ] } ],
      game_events(@player, Game::CardRemovedFromDecks).map(&:data)
  end

  test "the player's other copies and other decked editions stay as they were" do
    card, kept = ranked_cards(@player, 2, quantity: 3)
    Game::Holding.where(player_id: @player.id, card_season_id: card).update_all("reserved = reserved + 1")
    add(card, @first)
    add(kept, @first)

    assert_equal 1, free(card).value!

    assert_equal 1, reserved_of(@player, card)
    assert_equal 1, reserved_of(@player, kept)
    assert_equal({ 2 => kept }, Game::DeckSlots.call(@first))
  end

  test "an edition in no deck of the player writes nothing" do
    card = ranked_cards(@player, 1).sole
    other = accounts_players(:moderator)
    hold(other, card)
    their_deck = Game::CreateDeck.new.call(player: other).value!
    Game::AddCardToDeck.new.call(player: other, token: their_deck.token, card_season_id: card).value!

    assert_no_difference -> { writes } do
      assert_equal 0, free(card).value!
      assert_equal 0, free(nil).value!
    end
    assert_equal 1, Game::DeckCard.where(deck_id: their_deck.id).count
  end

  test "a visitor or a banned player is refused" do
    assert_equal :player_required, free(1, player: nil).failure
    @player.update_columns(banned_at: Time.current)
    assert_equal :player_required, free(1).failure
  end

  test "it locks the bank, then the decks, then their cards, then the holding" do
    card = ranked_cards(@player, 1).sole
    add(card, @first)
    add(card, @second)

    statements = recorded_sql { free(card).value! }
    advisory = statements.index { it.include?("pg_advisory_xact_lock") }
    decks = statements.index { it.start_with?(%(SELECT "game_decks")) && it.include?("FOR UPDATE") }
    cards = statements.index { it.start_with?(%(SELECT "game_deck_cards")) && it.include?("FOR UPDATE") }
    holdings = statements.index { it.include?(%(FROM "game_holdings")) && it.include?("FOR UPDATE") }

    assert_operator advisory, :<, decks
    assert_operator decks, :<, cards
    assert_operator cards, :<, holdings
    assert_match(/ORDER BY "game_decks"."id" ASC/, statements[decks])
    assert_match(/ORDER BY "game_deck_cards"."id" ASC/, statements[cards])
  end

  private
    def recorded_sql(&block)
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      statements
    end
end
