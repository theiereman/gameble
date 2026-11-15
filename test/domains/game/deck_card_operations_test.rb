require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/decks"

# Adding a card to a deck and taking it out: the lowest free slot, one edition of a game per deck, twelve cards, an
# owned and ranked edition with a free copy; a copy is reserved when its edition enters the player's first deck and
# freed when it leaves the last. A change already made writes nothing, so a save sent twice is harmless.
class Game::DeckCardOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include Decks

  setup do
    @player = accounts_players(:player)
    @deck = Game::CreateDeck.new.call(player: @player).value!
  end

  def add(card_season_id, deck: @deck, player: @player) = Game::AddCardToDeck.new.call(player:, token: deck.token, card_season_id:)

  def remove(card_season_id, deck: @deck, player: @player) = Game::RemoveCardFromDeck.new.call(player:, token: deck.token, card_season_id:)

  def second_deck = Game::CreateDeck.new.call(player: @player).value!

  def slots(deck = @deck) = Game::DeckSlots.call(deck)

  def writes = Game::DeckCard.count + Game::Holding.sum(:reserved) + Rails.configuration.event_store.read.count

  def assert_refused(code, &operation)
    assert_no_difference -> { writes } do
      assert_equal code, operation.call.failure
    end
  end

  test "a first deck entry takes slot 1, reserves a copy and writes one event; adding it again writes nothing" do
    card = ranked_cards(@player, 1).sole

    placed = add(card).value!

    assert_equal [ 1, 1 ], [ placed.slot, placed.count ]
    assert_equal({ 1 => card }, slots)
    assert_equal 1, reserved_of(@player, card)
    assert_equal [ { player_id: @player.id, deck_id: @deck.id, card_season_id: card } ], game_events(@player, Game::DeckCardAdded).map(&:data)
    assert_no_difference -> { writes } do
      assert_equal 1, add(card).value!.slot
    end
  end

  test "an edition in a second deck keeps one copy reserved until it leaves the last" do
    card = ranked_cards(@player, 1).sole
    other = second_deck
    add(card).value!

    add(card, deck: other).value!
    assert_equal 1, reserved_of(@player, card)

    remove(card).value!
    assert_equal 1, reserved_of(@player, card)

    remove(card, deck: other).value!
    assert_equal 0, reserved_of(@player, card)
    assert_equal 2, game_events(@player, Game::DeckCardRemoved).size
  end

  test "taking a card out leaves its slot empty, the next card takes the lowest free slot, and taking out a card not there writes nothing" do
    first, second, third = ranked_cards(@player, 3)
    [ first, second ].each { add(it).value! }

    assert_equal [ 1, 1 ], remove(first).value!.to_h.values
    assert_equal({ 2 => second }, slots)
    assert_equal 1, add(third).value!.slot
    assert_no_difference -> { writes } do
      assert remove(first).success?
    end
  end

  test "a copy reserved by a trade or a listing cannot enter a deck; one a deck already blocks can enter another" do
    traded, decked = ranked_cards(@player, 2)
    Game::Holding.where(player_id: @player.id, card_season_id: traded).update_all(reserved: 1)
    add(decked).value!
    other = second_deck

    assert_refused(:no_free_copy) { add(traded, deck: other) }
    assert add(decked, deck: other).success?
    assert_equal 1, reserved_of(@player, decked)
  end

  test "an edition the player does not own, or no longer holds, is refused" do
    held, emptied = ranked_cards(@player, 2)
    unowned = ranked_cards(accounts_players(:moderator), 1).sole
    Game::Holding.where(player_id: @player.id, card_season_id: emptied).update_all(quantity: 0)

    assert_refused(:card_not_owned) { add(unowned) }
    assert_refused(:card_not_owned) { add(emptied) }
    assert add(held).success?
  end

  test "an edition with no duel stats, or with no discovery value yet, is refused" do
    _season, (undiscovered,) = published_cards(1)
    hold(@player, undiscovered)
    rank([])
    _season, (unranked,) = published_cards(1)
    hold(@player, unranked)

    assert_nil Game::DuelProfiles.call([ unranked ])[unranked]
    assert_not Game::DuelProfiles.call([ undiscovered ]).fetch(undiscovered).stats.find { it.name == :discovery }.value?
    assert_refused(:not_yet_ranked) { add(unranked) }
    assert_refused(:not_yet_ranked) { add(undiscovered) }
  end

  test "a second edition of a game already in the deck is refused" do
    first = ranked_cards(@player, 1).sole
    second = second_editions([ first ]).sole
    hold(@player, second)
    rank([ second ])
    add(first).value!

    assert_refused(:game_already_in_deck) { add(second) }
  end

  test "a thirteenth card is refused" do
    cards = ranked_cards(@player, 13)
    cards.first(12).each { add(it).value! }

    assert_equal (1..12).to_a, slots.keys
    assert_refused(:deck_full) { add(cards.last) }
  end

  test "an add, a removal and a deletion lock the bank, then the deck and its cards, then the holdings" do
    card = ranked_cards(@player, 1).sole
    changes = [ -> { add(card).value! }, -> { remove(card).value! }, -> { add(card).value! },
      -> { Game::DeleteDeck.new.call(player: @player, token: @deck.token).value! } ]

    changes.each do |change|
      statements = recorded_sql(&change)
      advisory = statements.index { it.include?("pg_advisory_xact_lock") }
      deck = statements.index { it.include?(%(FROM "game_decks")) && it.include?("FOR UPDATE") }
      cards = statements.index { it.include?(%(FROM "game_deck_cards")) && it.include?("FOR UPDATE") }
      holdings = statements.index { it.include?(%(FROM "game_holdings")) && it.include?("FOR UPDATE") }

      assert_operator advisory, :<, deck
      assert_operator deck, :<, cards
      assert_operator cards, :<, holdings
    end
  end

  private
    def recorded_sql(&block)
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      statements
    end
end
