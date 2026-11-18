require "test_helper"
require_relative "../../support/decks"

# A deck's ten calls, each the deck's best percentile in it and a gap below 90.
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

  def coverage(deck) = Game::DeckCoverage.new(deck)

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
end
