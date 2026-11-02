require "test_helper"
require_relative "../../support/game_packs"

class Game::FortuneTest < ActiveSupport::TestCase
  include GamePacks

  MONDAY = Time.utc(2026, 10, 26)

  setup { @player = accounts_players(:player) }

  def ids(*names) = names.map { catalog_card_seasons(it).id }

  def open(idempotency_key: nil) = Game::OpenPack.new.call(player: @player, idempotency_key:).value!

  def tally(week_start = nil) = Game::Fortune.find_by!(player_id: @player.id, week_start:)

  def compared(fortune)
    fortune.attributes.except("id", "created_at", "updated_at").transform_values { it.is_a?(Float) ? it.round(9) : it }
  end

  test "an opened pack adds its cards' points, duplicates included, to the all-time and the week's tallies" do
    create_pack(@player, cards: ids(:legendary_card_one, :portal_one, :common_card_one, :portal_one, :common_card_one), available_at: MONDAY)

    travel_to(MONDAY + 3.hours) { open }

    [ tally, tally(MONDAY.to_date) ].each do |fortune|
      assert_equal 1, fortune.regular_packs
      assert_equal [ 0, 0 ], [ fortune.bonus_packs, fortune.reward_packs ]
      assert_equal({ 1 => 2, 2 => 0, 3 => 0, 4 => 2, 5 => 1 }, fortune.cards_by_tier)
      assert_equal 140, fortune.actual_points
      assert_in_delta 2.925, fortune.expected_points, 1e-9
      assert_in_delta 42.613875, fortune.variance, 1e-9
      assert_in_delta (140 - 2.925) / Math.sqrt(42.613875), fortune.z_score, 1e-9
    end
  end

  test "the packs of each kind add up, each with what its kind promises" do
    create_pack(@player, cards: ids(*[ :common_card_one ] * 5), available_at: 3.minutes.ago)
    create_pack(@player, kind: :bonus, cards: ids(:uncommon_card_one, :rare_card_one, :rare_card_one), available_at: 2.minutes.ago)
    2.times { open }

    fortune = tally
    assert_equal({ "regular" => 1, "bonus" => 1, "reward" => 0 }, fortune.packs_by_kind)
    assert_equal 11, fortune.actual_points
    assert_in_delta 2.925 + 11.7, fortune.expected_points, 1e-9
    assert_in_delta 42.613875 + 334.47, fortune.variance, 1e-9
  end

  test "a replayed opening counts once" do
    create_pack(@player, cards: ids(*[ :rare_card_one ] * 5))
    key = SecureRandom.uuid

    2.times { open(idempotency_key: key) }

    assert_equal [ 1, 25 ], [ tally.regular_packs, tally.actual_points ]
  end

  test "each week has its own tally, and the next one starts empty on Monday at midnight UTC" do
    create_pack(@player, cards: ids(*[ :rare_card_one ] * 5), available_at: MONDAY - 1.day)
    create_pack(@player, cards: ids(*[ :uncommon_card_one ] * 5), available_at: MONDAY - 1.day)

    travel_to(MONDAY - 1.second) { open }
    travel_to(MONDAY) do
      assert_equal 0, Game::Fortune.week_of(Time.current).count
      open
    end

    assert_equal [ 1, 25 ], [ tally(MONDAY.to_date - 7).regular_packs, tally(MONDAY.to_date - 7).actual_points ]
    assert_equal [ 1, 5 ], [ tally(MONDAY.to_date).regular_packs, tally(MONDAY.to_date).actual_points ]
    assert_equal [ 2, 30 ], [ tally.regular_packs, tally.actual_points ]
  end

  test "the backfill rebuilds from the opened packs exactly what the openings summed, and reruns idempotently" do
    create_pack(@player, cards: ids(:legendary_card_one, :portal_one, :common_card_one, :portal_one, :common_card_one), available_at: MONDAY - 9.days)
    create_pack(@player, kind: :bonus, cards: ids(:uncommon_card_one, :rare_card_one, :rare_card_one), available_at: MONDAY - 9.days)
    create_pack(@player, kind: :reward, cards: ids(*[ :portal_one ] * 5), available_at: MONDAY - 9.days)
    create_pack(@player, cards: ids(*[ :rare_card_one ] * 5), available_at: MONDAY)
    travel_to(MONDAY - 8.days) { 2.times { open } }
    travel_to(MONDAY + 1.hour) { 2.times { open } }
    summed = Game::Fortune.where(player_id: @player.id).order(:week_start).map { compared(it) }

    Game::Fortune.where(player_id: @player.id).delete_all
    assert_equal 1, Game::BackfillFortunesJob.players_out_of_tally
    2.times { Game::BackfillFortunesJob.perform_now }

    assert_equal summed, Game::Fortune.where(player_id: @player.id).order(:week_start).map { compared(it) }
    assert_equal 3, summed.size
    assert_equal 0, Game::BackfillFortunesJob.players_out_of_tally
  end

  test "a released player's tallies go with their packs" do
    create_pack(@player)
    open

    Game::ReleasePlayer.new.call(player: @player).value!

    assert_not Game::Fortune.exists?(player_id: @player.id)
  end
end
