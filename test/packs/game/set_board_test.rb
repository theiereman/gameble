require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

# Game::SetBoard: a player's sets in progress, closest first; and the hub's
# four, filled with the sets touched, then popular ones.
class Game::SetBoardTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  setup do
    @player = accounts_players(:player)
    # Reviews grow with the card: a set made of later cards is more popular.
    @season, @cards = published_cards(240, review_counts: Array.new(240) { |index| index.zero? ? nil : index * 10 })
    @free = @cards.dup
  end

  def take(count) = @free.shift(count)

  def theme(key, size)
    members = take(size)
    [ insert_theme(members, key:, season: @season), members ]
  end

  def untiered(kind, key, size)
    members = take(size)
    [ insert_set(members, { complete: size }, kind:, key:, params: { kind => key }, season: @season), members ]
  end

  def board(player = @player, **options) = Game::SetBoard.call(player, season: @season, **options)

  def ids(standings) = standings.map(&:set_id)

  test "closest to the next tier or completion first, then by share held" do
    franchise, franchise_cards = untiered("franchise", "dark-souls", 3)
    silver, silver_cards = theme("roguelike", 62)
    studio, studio_cards = untiered("studio", "supergiant", 5)
    gold, gold_cards = theme("metroidvania", 77)
    hold_all(@player, franchise_cards.first(2) + silver_cards.first(29) + studio_cards.first(3) + gold_cards.first(40))

    result = board
    assert_equal [ franchise, studio, silver, gold ], ids(result.in_progress)
    assert_equal [ 1, 2, 2, 37 ], result.in_progress.map(&:missing)
    assert_equal [ nil, nil, "silver", "gold" ], result.in_progress.map(&:reached_tier).map { it unless it == "complete" }
  end

  test "the sets the latest opening touched lead, the one it raised a tier of first" do
    closest, closest_cards = untiered("franchise", "dark-souls", 3)
    touched, touched_cards = theme("horror", 40)
    raised, raised_cards = theme("roguelike", 62)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(@player, closest_cards.first(2), gained_at: latest - 1.day)
    hold_all(@player, touched_cards.first(2), gained_at: latest)
    hold_all(@player, raised_cards.first(11), gained_at: latest - 1.day)
    hold_all(@player, [ raised_cards[11] ], gained_at: latest)
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: raised, tier: "bronze", reached_by: "trade", reached_at: latest, created_at: latest, updated_at: latest } ])

    result = board
    assert_equal [ raised, touched, closest ], ids(result.in_progress)
    assert_equal [ 12, "bronze" ], [ result.in_progress.first.held, result.in_progress.first.reached_tier ]
  end

  test "one game held touches a set: not in progress; the hub lists it, the latest touched first" do
    earlier, earlier_cards = theme("pirates", 18)
    latest_set, latest_cards = theme("horror", 18)
    never_timed, never_timed_cards = theme("cosy", 18)
    hold_all(@player, [ earlier_cards.first ], gained_at: 2.hours.ago)
    hold_all(@player, [ latest_cards.first ], gained_at: 1.hour.ago)
    hold_all(@player, [ never_timed_cards.first ])

    assert_empty board.in_progress
    hub = Game::SetBoard.hub(@player, season: @season)
    assert_equal [ latest_set, earlier, never_timed ], ids(hub).first(3)
    assert_equal [ 1, 1, 1 ], hub.first(3).map(&:held)
  end

  test "a player with nothing: no set in progress; the hub shows four popular sets at 0" do
    sets = (1..6).map { |index| theme("theme-#{index}", 20).first }

    result = board
    assert_empty result.in_progress
    assert_empty result.standings
    hub = Game::SetBoard.hub(@player, season: @season)
    assert_equal sets.last(4).reverse, ids(hub)
    assert hub.all? { it.held.zero? && it.total == 20 && it.tiers.key?("bronze") }
  end

  test "popular sets fill what is left of the hub, never a set already started" do
    started, started_cards = theme("theme-a", 20)
    popular = (1..5).map { |index| theme("theme-#{index}", 20).first }
    hold_all(@player, [ started_cards.first ], gained_at: 1.hour.ago)

    assert_equal [ started ] + popular.last(3).reverse, ids(Game::SetBoard.hub(@player, season: @season))
  end

  test "a set completed earlier is neither in progress nor in the hub; completed at the latest gain, it is in progress" do
    done, done_cards = untiered("franchise", "dark-souls", 3)
    fresh, fresh_cards = untiered("franchise", "portal", 2)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(@player, done_cards, gained_at: latest - 1.day)
    hold_all(@player, fresh_cards, gained_at: latest)
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: fresh, tier: "complete", reached_by: "trade", reached_at: latest, created_at: latest, updated_at: latest } ])

    result = board
    assert_equal [ fresh ], ids(result.in_progress)
    assert result.in_progress.first.complete?
    assert_not_includes ids(Game::SetBoard.hub(@player, season: @season)), done
    assert result.standings.fetch(done).complete?
  end

  test "in progress shows ten at most" do
    12.times { |index| hold_all(@player, theme("theme-#{index}", 10).last.first(2)) }

    assert_equal 10, board.in_progress.size
    assert_equal 3, board(in_progress: 3).in_progress.size
  end

  test "the same number of queries with three sets started or forty" do
    sets = (1..45).map { theme("theme-#{it}", 5).last }
    hold_all(@player, sets.first(3).map(&:first))
    three = nil
    assert_queries_count(1) { three = board }
    assert_equal 3, three.in_progress.size

    hold_all(@player, sets[3, 37].flat_map { it.first(2) })
    assert_queries_count(1) { board }
  end

  test "a visitor or no season: nothing and no query" do
    (1..5).each { |index| theme("theme-#{index}", 20) }

    assert_queries_count(0) { assert_equal Game::SetBoard::EMPTY, board(nil) }
    assert_queries_count(0) { assert_equal Game::SetBoard::EMPTY, Game::SetBoard.call(@player, season: nil) }
    assert_queries_count(0) { assert_equal [], Game::SetBoard.hub(@player, season: nil) }
  end

  test "the hub: the first four in progress, filled from the sets touched, then popular ones" do
    in_progress = (1..2).map { |index| theme("progress-#{index}", 10) }
    touched, touched_cards = theme("touched", 20)
    popular = (1..3).map { |index| theme("popular-#{index}", 10).first }
    in_progress.each { |_set, cards| hold_all(@player, cards.first(2)) }
    hold_all(@player, [ touched_cards.first ])

    assert_equal ids(board.in_progress) + [ touched, popular.last ], ids(Game::SetBoard.hub(@player, season: @season))
    assert_equal popular.last(3).reverse + [ touched ], ids(Game::SetBoard.hub(nil, season: @season))

    more = (1..5).map { |index| theme("more-#{index}", 10).last }
    more.each { hold_all(@player, it.first(3)) }
    hub = nil
    assert_queries_count(1) { hub = Game::SetBoard.hub(@player, season: @season) }
    assert_equal ids(board.in_progress).first(4), ids(hub)
  end
end
