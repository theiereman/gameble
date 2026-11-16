require "test_helper"
require_relative "../../support/decks"

# A deck's ten calls, each the deck's best percentile in it and a gap below 90; the fill picks the player's free,
# ranked editions of games not in the deck, the best for each gap still open, then the strongest trumps.
class Game::DeckCoverageTest < ActiveSupport::TestCase
  include Decks

  setup do
    @player = accounts_players(:player)
  end

  def deck_of(card_season_ids)
    deck = Game::CreateDeck.new.call(player: @player).value!
    card_season_ids.each { Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: it).value! }
    deck
  end

  def coverage(deck) = Game::DeckCoverage.new(@player, deck)

  def call_in(deck, key) = coverage(deck).calls.find { it.key == key }

  def call_at(best) = Game::DeckCoverage::Call.new(stat: :popularity, direction: "high", best:)

  # Covers every call but rating-low and release-high, each left at 50.
  def deck_missing_rating_low_and_release_high(first, second)
    set_percentiles(first, popularity: 95, rating: 95, discovery: 95, circulation: 95)
    set_percentiles(second, popularity: 5, rating: 50, release: 5, discovery: 5, circulation: 5)
    deck_of([ first, second ])
  end

  test "a call's best is the deck's top percentile in its direction, and a call under 90 is a gap" do
    first, second = ranked_cards(@player, 2)
    set_percentiles(first, popularity: 95)
    set_percentiles(second, popularity: 30)
    deck = deck_of([ first, second ])

    high = call_in(deck, "popularity-high")
    low = call_in(deck, "popularity-low")

    assert_equal [ 95, false, 95 ], [ high.best, high.gap?, high.shown ]
    assert_equal [ 70, true, 70 ], [ low.best, low.gap?, low.shown ]
  end

  test "90.0 covers a call and 89.9 leaves a gap; the shown value is rounded into 0 to 99" do
    card = ranked_cards(@player, 1).sole
    set_percentiles(card, popularity: BigDecimal("90.0"), rating: BigDecimal("89.9"))
    deck = deck_of([ card ])

    assert_not call_in(deck, "popularity-high").gap?
    assert call_in(deck, "rating-high").gap?
    assert_equal [ 99, 99, 0, nil ], [ call_at(100).shown, call_at(BigDecimal("99.6")).shown, call_at(BigDecimal("0.2")).shown, call_at(nil).shown ]
    assert call_at(nil).gap?
  end

  test "an empty deck, or no deck yet, has the ten calls in stat order, each a gap with no best" do
    expected = %w[popularity rating release discovery circulation].flat_map { [ "#{it}-high", "#{it}-low" ] }

    [ deck_of([]), nil ].each do |deck|
      calls = coverage(deck).calls

      assert_equal expected, calls.map(&:key)
      assert calls.all? { it.gap? && it.best.nil? }
    end
  end

  test "the fill takes the best card for each gap in call order, then the strongest trumps, for the room given" do
    first, second, x, y, z, w = ranked_cards(@player, 6)
    deck = deck_missing_rating_low_and_release_high(first, second)
    set_percentiles(x, rating: 5)
    set_percentiles(y, release: 97)
    set_percentiles(z, circulation: 99)
    set_percentiles(w, popularity: 60)

    assert_equal [ x, y, z ], coverage(deck).fill(room: 3)
    assert_equal [ x, y ], coverage(deck).fill(room: 2)
    assert_equal [ x, y, z, w ], coverage(deck).fill(room: 12)
  end

  test "a gap a card already picked closes is not filled again" do
    first, second, x, y, z = ranked_cards(@player, 5)
    set_percentiles(first, popularity: 50, rating: 95, discovery: 95, circulation: 95)
    set_percentiles(second, popularity: 5, rating: 5, release: 5, discovery: 5, circulation: 5)
    deck = deck_of([ first, second ])
    set_percentiles(x, popularity: 96, release: 95)
    set_percentiles(y, release: 99)
    set_percentiles(z, circulation: 100)

    assert_equal [ true, true ], [ call_in(deck, "popularity-high").gap?, call_in(deck, "release-high").gap? ]
    assert_equal [ x, z ], coverage(deck).fill(room: 2)
  end

  test "equal cards go by the lower card-season, and a card with no value in a call is never its pick" do
    valueless, first, later = ranked_cards(@player, 3)
    set_percentiles(valueless, popularity: nil)
    set_percentiles(first)
    set_percentiles(later)

    assert_equal [ first ], coverage(nil).fill(room: 1)
    assert_equal [ first, later, valueless ], coverage(nil).fill(room: 3)
  end

  test "a pick drops the other editions of its game" do
    plain, other = ranked_cards(@player, 2)
    second = second_editions([ plain ]).sole
    hold(@player, second)
    rank([ second ])
    set_percentiles(plain)
    set_percentiles(other)
    set_percentiles(second, popularity: 99)

    assert_equal [ second, other ], coverage(nil).fill(room: 12)
  end

  test "an edition of a game in the deck, an unranked edition and one a trade fully reserves are never picked" do
    in_deck, free, traded = ranked_cards(@player, 3)
    second = second_editions([ in_deck ]).sole
    hold(@player, second)
    _season, (unranked,) = published_cards(1)
    hold(@player, unranked)
    rank([ second ])
    Game::Holding.where(player_id: @player.id, card_season_id: traded).update_all(reserved: 1)
    [ in_deck, free ].each { set_percentiles(it) }
    set_percentiles(second, popularity: 99)
    set_percentiles(traded, rating: 99)
    deck = deck_of([ in_deck ])

    assert_equal [ free ], coverage(deck).fill(room: 11)
  end

  test "an edition whose only copy another deck blocks can be picked" do
    card = ranked_cards(@player, 1).sole
    deck_of([ card ])

    assert_equal 1, reserved_of(@player, card)
    assert_equal [ card ], coverage(deck_of([])).fill(room: 12)
  end
end
