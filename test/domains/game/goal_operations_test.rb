require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"
require_relative "../../support/custom_sets"
require_relative "../../support/holdings"

# Marking and unmarking goals: up to five, each on a game set of the
# published season or one of the player's custom sets, taking the lowest
# free number and keeping it; each change writes one event, a refusal
# writes nothing.
class Game::GoalOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include GameSets
  include CustomSets
  include Holdings

  setup do
    @player = accounts_players(:player)
  end

  def add(player: @player, **aim) = Game::AddGoal.new.call(player:, **aim)

  def remove(player: @player, **aim) = Game::RemoveGoal.new.call(player:, **aim)

  def theme(key, size: 3) = insert_set(unheld_cards(size), { complete: size }, key:, params: { "theme" => key })

  def positions = Game::Goal.where(player_id: @player.id).order(:position).pluck(:position, :set_kind, :set_key)

  def writes = Game::Goal.count + Rails.configuration.event_store.read.count

  def assert_refused(code, &operation)
    assert_no_difference -> { writes } do
      assert_equal code, operation.call.failure
    end
  end

  test "a first goal on a game set of the published season takes number 1 and writes one event" do
    theme("roguelike")

    goal = add(kind: "theme", key: "roguelike").value!

    assert_equal [ 1, "theme", "roguelike", @player.id, nil ], [ goal.position, goal.set_kind, goal.set_key, goal.player_id, goal.custom_set_id ]
    assert_equal [ { player_id: @player.id, goal_id: goal.id } ], game_events(@player, Game::GoalAdded).map(&:data)
  end

  test "a new goal takes the lowest free number and the others keep theirs" do
    %w[roguelike horror cosy rpg].each { theme(it) }
    %w[roguelike horror cosy].each { add(kind: "theme", key: it).value! }

    removed = remove(kind: "theme", key: "horror").value!
    assert_equal 2, removed.position
    assert_equal [ { player_id: @player.id, goal_id: removed.id } ], game_events(@player, Game::GoalRemoved).map(&:data)

    assert_equal 2, add(kind: "theme", key: "rpg").value!.position
    assert_equal [ [ 1, "theme", "roguelike" ], [ 2, "theme", "rpg" ], [ 3, "theme", "cosy" ] ], positions
  end

  test "a sixth goal is refused" do
    %w[a1 a2 a3 a4 a5 a6].each { theme(it) }
    %w[a1 a2 a3 a4 a5].each { add(kind: "theme", key: it).value! }

    assert_refused(:too_many_goals) { add(kind: "theme", key: "a6") }
  end

  test "a set already a goal stays as it is, at five goals too" do
    %w[a1 a2 a3 a4 a5].each { theme(it) }
    first = add(kind: "theme", key: "a1").value!
    %w[a2 a3 a4 a5].each { add(kind: "theme", key: it).value! }

    assert_no_difference -> { writes } do
      assert_equal first, add(kind: "theme", key: "a1").value!
    end
  end

  test "removing a set that is no goal writes nothing" do
    theme("roguelike")

    assert_no_difference -> { writes } do
      assert_nil remove(kind: "theme", key: "roguelike").value!
      assert_nil remove(custom_set: "x" * 24).value!
      assert_nil remove(kind: [ "theme" ], key: "roguelike").value!
    end
  end

  test "a kind outside the set kinds, a key outside the published season, or no published season, is refused" do
    theme("roguelike")

    assert_refused(:goal_set_not_found) { add(kind: "tribute", key: "roguelike") }
    assert_refused(:goal_set_not_found) { add(kind: "theme", key: "pirates") }
    assert_refused(:goal_set_not_found) { add(kind: "theme", key: nil) }
    assert_refused(:goal_set_not_found) { add(kind: { "x" => "theme" }, key: "roguelike") }
    assert_refused(:goal_set_not_found) { add }
    without_published_season { assert_refused(:goal_set_not_found) { add(kind: "theme", key: "roguelike") } }
  end

  test "a game set of an earlier season only is refused" do
    season, = published_cards(3)
    theme("roguelike")
    assert_equal season, Catalog::PublishedSeason.call

    assert_refused(:goal_set_not_found) { add(kind: "theme", key: "roguelike") }
  end

  test "a custom set is a goal by its token; another player's or the Steam library set is refused" do
    mine = create_custom_set(@player)
    theirs = create_custom_set(accounts_players(:moderator))
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)

    goal = add(custom_set: mine.token).value!
    assert_equal [ 1, mine.id, nil ], [ goal.position, goal.custom_set_id, goal.set_kind ]

    assert_refused(:custom_set_not_found) { add(custom_set: theirs.token) }
    assert_refused(:custom_set_not_found) { add(custom_set: library.token) }
    assert_refused(:custom_set_not_found) { add(custom_set: [ mine.token ]) }
    assert_no_difference -> { writes } do
      assert_nil remove(custom_set: theirs.token).value!
    end

    assert_equal goal, remove(custom_set: mine.token).value!
    assert_empty Game::Goal.where(player_id: @player.id)
  end

  test "a set whose every game the player holds is refused" do
    hold(@player, catalog_card_seasons(:portal_one).id)

    assert_refused(:goal_set_complete) { add(kind: "studio", key: "valve") }
  end

  test "a custom set whose every game the player holds is refused" do
    ids = fixture_card_ids.first(3)
    custom_set = create_custom_set(@player, card_ids: ids)
    ids.each { |card_id| hold(@player, Catalog::CardSeason.find_by!(card_id:).id) }

    assert_refused(:goal_set_complete) { add(custom_set: custom_set.token) }
  end

  test "a banned, deleted or missing player is refused" do
    theme("roguelike")
    deleted = accounts_players(:moderator)
    deleted.update_columns(deleted_at: Time.current, steam_id: nil)

    [ nil, Accounts::Player.new, accounts_players(:banned), deleted ].each do |player|
      assert_refused(:player_required) { add(player:, kind: "theme", key: "roguelike") }
      assert_refused(:player_required) { remove(player:, kind: "theme", key: "roguelike") }
    end
  end

  test "deleting a custom set takes its goal with it" do
    custom_set = create_custom_set(@player)
    add(custom_set: custom_set.token).value!

    Game::DeleteCustomSet.new.call(player: @player, token: custom_set.token).value!

    assert_empty Game::Goal.where(player_id: @player.id)
  end

  test "the table refuses a sixth number, two targets, none, and a kind outside the set kinds" do
    theme("roguelike")
    custom_set = create_custom_set(@player)
    rows = [
      { position: 6, set_kind: "theme", set_key: "roguelike" },
      { position: 1, set_kind: "theme", set_key: "roguelike", custom_set_id: custom_set.id },
      { position: 1 },
      { position: 1, set_kind: "theme" },
      { position: 1, set_kind: "tribute", set_key: "roguelike" }
    ]
    rows.each do |row|
      assert_raises(ActiveRecord::StatementInvalid, row.inspect) do
        Game::Goal.transaction(requires_new: true) { Game::Goal.create!(player_id: @player.id, **row) }
      end
    end
  end
end
