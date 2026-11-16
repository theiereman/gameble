require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/decks"

# Filling a deck's empty slots at once: the coverage's picks take the lowest free slots in pick order, each reserving a
# copy unless another deck already blocks one, under one event; a pick any single add would refuse refuses the whole
# fill, and a fill with nothing to pick writes nothing.
class Game::FillDeckGapsTest < ActiveSupport::TestCase
  include GamePacks
  include Decks

  setup do
    @player = accounts_players(:player)
    @deck = Game::CreateDeck.new.call(player: @player).value!
  end

  def fill(deck: @deck, player: @player) = Game::FillDeckGaps.new.call(player:, token: deck.token)

  def add(card_season_id, deck: @deck) = Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id:).value!

  def slots(deck = @deck) = Game::DeckSlots.call(deck)

  def writes = Game::DeckCard.count + Game::Holding.sum(:reserved) + Rails.configuration.event_store.read.count

  test "the picks take the lowest free slots in pick order, each reserving a copy, under one event" do
    first, second, x, y, z, *fillers = ranked_cards(@player, 13)
    set_percentiles(first, popularity: 95, rating: 95, discovery: 95, circulation: 95)
    set_percentiles(second, popularity: 5, rating: 50, release: 5, discovery: 5, circulation: 5)
    set_percentiles(x, rating: 5)
    set_percentiles(y, release: 97)
    set_percentiles(z, circulation: 99)
    fillers.each { set_percentiles(it) }
    [ first, fillers.first, second, *fillers.drop(1) ].each { add(it) }
    Game::RemoveCardFromDeck.new.call(player: @player, token: @deck.token, card_season_id: fillers.first).value!
    assert_equal [ 1, *3..10 ], slots.keys

    filled = fill.value!

    assert_equal [ [ 2, x ], [ 11, y ], [ 12, z ] ], filled.placed
    assert_equal 12, filled.count
    assert_equal [ x, y, z ], slots.values_at(2, 11, 12)
    assert_equal [ 1, 1, 1 ], [ x, y, z ].map { reserved_of(@player, it) }
    assert_equal [ { player_id: @player.id, deck_id: @deck.id, card_season_ids: [ x, y, z ] } ], game_events(@player, Game::DeckGapsFilled).map(&:data)
  end

  test "an edition another deck blocks is picked and keeps its one reserved copy" do
    card = ranked_cards(@player, 1).sole
    add(card, deck: Game::CreateDeck.new.call(player: @player).value!)

    assert_equal [ [ 1, card ] ], fill.value!.placed
    assert_equal 1, reserved_of(@player, card)
  end

  test "a full deck, or a player with nothing to pick, succeeds and writes nothing" do
    cards = ranked_cards(@player, 13)
    cards.first(12).each { add(it) }
    other = Game::CreateDeck.new.call(player: accounts_players(:moderator)).value!

    assert_no_difference -> { writes } do
      assert_equal [ [], 12 ], fill.value!.to_h.values
      assert_equal [ [], 0 ], fill(deck: other, player: accounts_players(:moderator)).value!.to_h.values
    end
  end

  test "a pick a single add would refuse refuses the whole fill: no card, no reserved copy, no event" do
    good, raced = ranked_cards(@player, 2)
    set_percentiles(good, popularity: 99)
    set_percentiles(raced, popularity: 1)
    Game::Holding.where(player_id: @player.id, card_season_id: raced).update_all(reserved: 1)

    with_copies_read_free(raced) do
      assert_no_difference -> { writes } do
        assert_equal :no_free_copy, fill.failure
      end
    end
  end

  test "a deck of another player is not found, and a player is required" do
    other = Game::CreateDeck.new.call(player: accounts_players(:moderator)).value!

    assert_equal :deck_not_found, fill(deck: other).failure
    assert_equal :player_required, fill(player: nil).failure
  end

  test "a fill locks the bank, then the deck and its cards, then the picks' cards in other decks, then their holdings" do
    ranked_cards(@player, 2)

    statements = recorded_sql { fill.value! }
    advisory = statements.index { it.include?("pg_advisory_xact_lock") }
    deck = statements.index { it.include?(%(FROM "game_decks")) && it.include?("FOR UPDATE") }
    cards, elsewhere = statements.each_index.select { statements[it].include?(%(FROM "game_deck_cards")) && statements[it].include?("FOR UPDATE") }
    holdings = statements.index { it.include?(%(FROM "game_holdings")) && it.include?("FOR UPDATE") }

    assert_operator advisory, :<, deck
    assert_operator deck, :<, cards
    assert_operator cards, :<, elsewhere
    assert_operator elsewhere, :<, holdings
  end

  private
    # The fill's unlocked read sees the copy free, as it would just before a concurrent trade reserves it.
    def with_copies_read_free(card_season_id)
      held_copies = Game::HeldCopies.method(:call)
      Game::HeldCopies.define_singleton_method(:call) do |player|
        held_copies.call(player).merge(card_season_id => Game::HeldCopies::Row.new(quantity: 1, reserved: 0))
      end
      yield
    ensure
      Game::HeldCopies.define_singleton_method(:call, held_copies)
    end

    def recorded_sql(&block)
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      statements
    end
end
