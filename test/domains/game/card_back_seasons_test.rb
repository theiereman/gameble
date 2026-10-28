require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"

class Game::CardBackSeasonsTest < ActiveSupport::TestCase
  include GamePacks
  include GameSets

  BACK = "set-theme-roguelike".freeze

  setup do
    @player = accounts_players(:player)
    tiers = { novice: 1, apprentice: 2, adept: 3, complete: 5 }
    @first = insert_set([], tiers, key: "roguelike", season: catalog_seasons(:one))
    @latest_season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    @second = insert_set([], tiers, key: "roguelike", season: @latest_season)
  end

  def reach(set_id, tier, reached_by: "trade")
    Game::SetTier.create!(player_id: @player.id, set_id:, tier:, reached_by:, reached_at: Time.current)
  end

  def reach_both_seasons
    reach(@first, "adept")
    reach(@second, "adept", reached_by: "allocation")
    Game::CardBackUnlock.record(@player.id, BACK, Time.current)
  end

  def choose(season = nil, back: BACK) = Game::ChooseCardBack.new.call(player: @player, back:, season:)

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_card_back, :active_card_back_season)

  test "a back earned in two seasons lists both, a carried tier counting for its season" do
    reach(@first, "adept")
    reach(@second, "adept", reached_by: "allocation")

    assert_equal({ BACK => [ 1, 2 ] }, Game::CardBackSeasons.call(@player))
  end

  test "a tier below the back tier earns nothing" do
    reach(@first, "novice")

    assert_empty Game::CardBackSeasons.call(@player)
  end

  test "choosing a back earned in two seasons stores the picked season" do
    reach_both_seasons

    assert choose(1).success?
    assert_equal [ BACK, 1 ], stored
    assert_equal [ BACK, 1 ], Game::CardBacks.active_with_season(@player)
  end

  test "choosing it without a season stores the latest one" do
    reach_both_seasons

    assert choose.success?
    assert_equal [ BACK, 2 ], stored
  end

  test "the season is published with the choice" do
    reach_both_seasons
    choose(1)

    assert_equal [ { player_id: @player.id, back: BACK, season: 1 } ], game_events(@player, Game::CardBackChosen).map(&:data)
  end

  test "a season the back was not earned in is refused and changes nothing" do
    reach(@first, "adept")
    Game::CardBackUnlock.record(@player.id, BACK, Time.current)

    result = choose(2)

    assert_equal :unknown_season, result.failure
    assert_nil Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)
  end

  test "a season that is not a number is refused" do
    reach_both_seasons

    assert_equal :unknown_season, choose("second").failure
  end

  test "a back earned once keeps no season" do
    reach(@first, "adept")
    Game::CardBackUnlock.record(@player.id, BACK, Time.current)

    assert choose(1).success?
    assert_equal [ BACK, nil ], stored
  end

  test "choosing another back clears the season" do
    reach_both_seasons
    choose(1)

    assert choose(nil, back: "standard").success?
    assert_equal [ "standard", nil ], stored
  end

  test "the opened pack stores the season the active back wore" do
    Game::CardBackUnlock.record(@player.id, BACK, Time.current)
    Game::PlayerState.insert({ player_id: @player.id }, unique_by: :player_id)
    Game::PlayerState.where(player_id: @player.id).update_all(active_card_back: BACK, active_card_back_season: 3)
    create_pack(@player, cards: fixture_tier_ids, available_at: 2.minutes.ago)
    @latest_season.update!(status: :draft)

    Game::OpenPack.new.call(player: @player).value!

    pack = Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).order(:opened_at).last
    assert_equal [ BACK, 3 ], [ pack.card_back, pack.card_back_season ]
  end

  test "a pack opened with the standard back stores no season" do
    create_pack(@player, cards: fixture_tier_ids, available_at: 2.minutes.ago)
    @latest_season.update!(status: :draft)

    Game::OpenPack.new.call(player: @player).value!

    pack = Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).order(:opened_at).last
    assert_equal [ "standard", nil ], [ pack.card_back, pack.card_back_season ]
  end

  test "the shelf offers the seasons of the active back and the one it wears" do
    reach_both_seasons
    choose(2)

    row = Game::CardBackShelf.call(@player).find(&:active?)

    assert_equal [ BACK, 2, [ 1, 2 ] ], [ row.key, row.season, row.seasons ]
    assert_predicate row, :choosable_season?
  end

  test "a back earned once offers no choice on the shelf" do
    reach(@first, "adept")
    Game::CardBackUnlock.record(@player.id, BACK, Time.current)

    row = Game::CardBackShelf.call(@player).find { it.key == BACK }

    assert_not_predicate row, :choosable_season?
  end
end
