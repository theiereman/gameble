require "test_helper"
require_relative "../../support/duels"

# The bot's decks: each archetype builds twelve different games from the pool, and any deck is named by what it holds.
class Game::DeckArchetypesTest < ActiveSupport::TestCase
  include Duels

  def build(name, pool) = Game::DeckArchetypes.build(name, pool, random: Random.new(7))

  def classify(cards) = Game::DeckArchetypes.classify(cards)

  def random_pool
    random = Random.new(42)
    games = Array.new(60) { duel_card(1001 + it, **Game::DuelStat::STATS.index_with { random.rand(0..100) }) }
    games + [ duel_card(1061, popularity: 99).with(card_id: games.first.card_id) ]
  end

  test "every archetype builds twelve different games from the pool" do
    pool = random_pool

    Game::DeckArchetypes::NAMES.each do |name|
      deck = build(name, pool)

      assert_equal 12, deck.size, name
      assert_equal 12, deck.map(&:card_id).uniq.size, name
      assert_empty ids(deck) - ids(pool), name
    end
  end

  test "a pool of fewer than twelve games builds a smaller deck" do
    assert_equal 8, build("rating", random_pool.first(8)).size
  end

  test "coverage takes the strongest card left for a call no card reaches ninety on" do
    pool = Array.new(20) { duel_card(2001 + it) } + [ duel_card(2021, popularity: 80) ]

    assert_includes ids(build("coverage", pool)), 2021
  end

  test "a deck is named by the calls it holds strong" do
    coverage = Game::DuelStat::STATS.each_with_index.flat_map do |stat, index|
      [ duel_card(3001 + (2 * index), stat => 95), duel_card(3002 + (2 * index), stat => 5) ]
    end
    coverage += [ duel_card(3011), duel_card(3012) ]
    rating = Array.new(12) { duel_card(3101 + it, rating: 95) }
    two_stats = Array.new(6) { duel_card(3201 + it, popularity: 95) } + Array.new(6) { duel_card(3207 + it, release: 3) }
    trumps = Array.new(12) { duel_card(3301 + it, Game::DuelStat::STATS[it % 5] => 99) }
    even = Array.new(12) { duel_card(3401 + it) }

    assert_equal "coverage", classify(coverage)
    assert_equal "rating", classify(rating)
    assert_equal "two_stats", classify(two_stats)
    assert_equal "trumps", classify(trumps)
    assert_equal Game::DeckArchetypes::OTHER, classify(even)
  end
end
