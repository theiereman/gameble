require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"
require_relative "../../support/game_trades"
require_relative "../../support/custom_sets"
require_relative "../../support/holdings"

# A goal leaves the goals by itself, freeing its number: when an opening or
# a trade completes its set, or its owner edits a custom set down to games
# they hold, within that change; when a newly published
# season no longer holds its game set; with its custom set.
class Game::GoalsReachedTest < ActiveSupport::TestCase
  include GamePacks
  include GameSets
  include GameTrades
  include CustomSets
  include Holdings

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @portal = catalog_card_seasons(:portal_one).id
  end

  def add(player = @player, **aim) = Game::AddGoal.new.call(player:, **aim).value!

  def goals(player = @player) = Game::Goal.where(player_id: player.id).order(:position).pluck(:position, :set_kind, :set_key, :custom_set_id)

  test "an opening that completes a goal's set takes the goal out, the other goals kept with their numbers" do
    insert_set([ catalog_card_seasons(:common_card_one).id, *unheld_cards(2) ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    add(kind: "theme", key: "roguelike")
    add(kind: "studio", key: "valve")
    create_pack(@player, cards: Array.new(Game::Pack::SIZE, @portal))

    Game::OpenPack.new.call(player: @player).value!

    assert_equal [ [ 1, "theme", "roguelike", nil ] ], goals
    assert_empty game_events(@player).grep(Game::GoalRemoved)
  end

  test "a custom set its owner edits down to games they all hold leaves the goals" do
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.values_at(0, 1, 4))
    hold(@player, catalog_card_seasons(:common_card_one).id)
    hold(@player, catalog_card_seasons(:legendary_card_one).id)
    hold(@player, @portal)
    add(custom_set: custom_set.token)

    Game::EditCustomSet.new.call(player: @player, token: custom_set.token, name: custom_set.name, card_ids: fixture_card_ids.values_at(0, 3, 4)).value!

    assert_empty goals
  end

  test "a custom set edited without completing it keeps its goal" do
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.values_at(0, 1, 4))
    hold(@player, catalog_card_seasons(:common_card_one).id)
    add(custom_set: custom_set.token)

    Game::EditCustomSet.new.call(player: @player, token: custom_set.token, name: "Mes jeux", card_ids: fixture_card_ids.values_at(0, 2, 4)).value!

    assert_equal [ [ 1, nil, nil, custom_set.id ] ], goals
  end

  test "a custom set completed by an opening leaves the goals" do
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.values_at(0, 3, 4))
    hold(@player, catalog_card_seasons(:common_card_one).id)
    hold(@player, catalog_card_seasons(:legendary_card_one).id)
    add(custom_set: custom_set.token)
    create_pack(@player, cards: Array.new(Game::Pack::SIZE, @portal))

    Game::OpenPack.new.call(player: @player).value!

    assert_empty goals
  end

  test "an accepted trade that completes a goal of both players takes out both goals, the others kept" do
    rare = catalog_card_seasons(:rare_card_one).id
    insert_set([ rare ], { complete: 1 }, key: "roguelike", params: { "theme" => "roguelike" })
    insert_set(unheld_cards(3), { complete: 3 }, key: "cosy", params: { "theme" => "cosy" })
    add(kind: "theme", key: "cosy")
    add(kind: "studio", key: "valve")
    add(@friend, kind: "theme", key: "roguelike")

    conclude_trade(@friend, @player, offer: { @portal => 1 }, request: { rare => 1 })

    assert_equal [ [ 1, "theme", "cosy", nil ] ], goals
    assert_empty goals(@friend)
  end

  test "a newly published season drops the goals on game sets it no longer holds, silently, and keeps the others" do
    insert_set([ catalog_card_seasons(:common_card_one).id, *unheld_cards(2) ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    insert_set([ catalog_card_seasons(:rare_card_one).id, *unheld_cards(2) ], { complete: 3 }, key: "cosy", params: { "theme" => "cosy" })
    custom_set = create_custom_set(@player)
    add(kind: "theme", key: "cosy")
    add(kind: "theme", key: "roguelike")
    add(custom_set: custom_set.token)
    add(@friend, kind: "studio", key: "valve")

    publish_sets_draft

    assert_equal [ [ 2, "theme", "roguelike", nil ], [ 3, nil, nil, custom_set.id ] ], goals
    assert_empty goals(@friend)
    assert_empty game_events(@player).grep(Game::GoalRemoved)
  end

  test "deleting the account erases the goals" do
    add(kind: "studio", key: "valve")
    add(custom_set: create_custom_set(@player).token)

    Game::ReleasePlayer.new.call(player: @player).value!

    assert_empty goals
  end
end
