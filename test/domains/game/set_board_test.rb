require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

# Game::SetBoard: a player's sets in progress, closest first, and their
# complete sets, the latest gained in first; and the hub's four, filled with
# the sets touched, then popular ones.
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

  def board(player = @player) = Game::SetBoard.call(player, season: @season)

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

  test "a set completed earlier is not in progress; completed at the latest gain, it is in progress" do
    done, done_cards = untiered("franchise", "dark-souls", 3)
    fresh, fresh_cards = untiered("franchise", "portal", 2)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(@player, done_cards, gained_at: latest - 1.day)
    hold_all(@player, fresh_cards, gained_at: latest)
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: fresh, tier: "complete", reached_by: "trade", reached_at: latest, created_at: latest, updated_at: latest } ])

    result = board
    assert_equal [ fresh ], ids(result.in_progress)
    assert result.in_progress.first.complete?
    assert_not_includes ids(result.in_progress), done
  end

  test "every complete set, the latest completed first, but one still in progress" do
    older, older_cards = untiered("franchise", "dark-souls", 3)
    newer, newer_cards = theme("roguelike", 20)
    fresh, fresh_cards = untiered("franchise", "portal", 2)
    untimed, untimed_cards = untiered("studio", "supergiant", 2)
    _started, started_cards = theme("horror", 20)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(@player, older_cards, gained_at: latest - 3.days)
    hold_all(@player, newer_cards, gained_at: latest - 1.day)
    hold_all(@player, untimed_cards)
    hold_all(@player, started_cards.first(5), gained_at: latest - 2.days)
    hold_all(@player, fresh_cards, gained_at: latest)
    record_completion(fresh, latest)

    result = board
    assert_equal [ newer, older, untimed ], ids(result.complete)
    assert result.complete.all?(&:complete?)
    assert_equal [ fresh ], ids(result.in_progress) & [ fresh, newer, older, untimed ]
  end

  test "a duplicate gained in a set completed long ago leaves it behind the set completed since" do
    long_ago, long_ago_cards = untiered("franchise", "dark-souls", 3)
    since, since_cards = untiered("franchise", "portal", 2)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(@player, long_ago_cards, gained_at: latest - 30.days)
    record_completion(long_ago, latest - 30.days)
    hold_all(@player, since_cards, gained_at: latest - 2.days)
    record_completion(since, latest - 2.days)
    Game::Holding.where(player_id: @player.id, card_season_id: long_ago_cards.first).update_all(quantity: 2, last_gained_at: latest - 1.day)
    _other, other_cards = theme("horror", 20)
    hold_all(@player, other_cards.first(1), gained_at: latest)

    assert_equal [ since, long_ago ], ids(board.complete)
  end

  def record_completion(set_id, at)
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id:, tier: "complete", reached_by: "trade", reached_at: at, created_at: at, updated_at: at } ])
  end

  test "the same number of queries with three sets started or forty" do
    sets = (1..45).map { theme("theme-#{it}", 5).last }
    hold_all(@player, sets.first(3).map(&:first))
    three = nil
    assert_queries_count(1) { three = board }
    assert_equal 3, three.in_progress.size

    hold_all(@player, sets[3, 37].flat_map { it.first(2) } + sets[40, 5].flatten)
    forty = nil
    assert_queries_count(1) { forty = board }
    assert_equal [ 40, 5 ], [ forty.in_progress.size, forty.complete.size ]
  end

  test "a visitor or no season: nothing and no query" do
    (1..5).each { |index| theme("theme-#{index}", 20) }

    assert_queries_count(0) { assert_equal Game::SetBoard::EMPTY, board(nil) }
    assert_queries_count(0) { assert_equal Game::SetBoard::EMPTY, Game::SetBoard.call(@player, season: nil) }
  end
end
