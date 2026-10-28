require "test_helper"
require_relative "../../support/second_season"

class Game::SeasonAllocationTest < ActiveSupport::TestCase
  include SecondSeason

  setup do
    @player = accounts_players(:player)
    @season, @set = publish_second_season(@player)
  end

  def state = Game::PlayerState.find_by!(player_id: @player.id)

  test "a player with an earlier card and an unseen season is pending" do
    assert Game::SeasonAllocationPending.call(@player)
  end

  test "nobody is pending once the season is seen, without an earlier card, or when signed out" do
    assert_not Game::SeasonAllocationPending.call(nil)

    Game::Holding.where(player_id: @player.id).delete_all
    assert_not Game::SeasonAllocationPending.call(@player)

    hold(@player, fixture_tier_ids.first)
    Game::PlayerState.where(player_id: @player.id).update_all(allocation_seen_season: 2)
    assert_not Game::SeasonAllocationPending.call(@player)
  end

  test "the pending check writes nothing and works in a read-only request" do
    assert_no_difference -> { Game::SetTier.count } do
      ApplicationRecord.connected_to(role: :reading, prevent_writes: true) { Game::SeasonAllocationPending.call(@player) }
    end
  end

  test "the recap previews the carried tiers before the allocation, without writing" do
    recap = nil
    assert_no_difference -> { Game::SetTier.count } do
      recap = Game::SeasonAllocationRecap.call(@player)
    end

    assert_equal [ 2, 1 ], [ recap.season_number, recap.ended_season_number ]
    assert_equal %w[novice apprentice adept], recap.received.map(&:tier)
    assert_equal [ @set ], recap.received.map { it.set.id }.uniq
  end

  test "the recap lists tiers earned in the ended season and its achievements, not the weekly rewards" do
    first_set = Catalog::Set.where(season_id: Catalog::Season.find_by!(number: 1).id).first
    first_set ||= Catalog::Set.create!(season: Catalog::Season.find_by!(number: 1), kind: "theme", key: "old", params: { "theme" => "old" })
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: first_set.id, tier: "bronze", held: 1, reached_by: "trade", reached_at: 1.day.ago, created_at: Time.current, updated_at: Time.current } ])
    Game::AchievementUnlock.record(@player.id, Game::Achievements::CATALOGUE.first.key, 1.day.ago)

    recap = Game::SeasonAllocationRecap.call(@player)

    assert_equal [ "bronze" ], recap.earned.map(&:tier)
    assert_equal [ Game::Achievements::CATALOGUE.first.key ], recap.achievements.map(&:key)
  end

  test "marking the allocation seen receives it, sets the marker and publishes no tier event" do
    result = Game::MarkAllocationSeen.new.call(player: @player)

    assert result.success?
    assert_equal [ 2, 2 ], [ state.allocation_received_season, state.allocation_seen_season ]
    assert_equal %w[novice apprentice adept], Game::SetTier.where(player_id: @player.id, reached_by: "allocation").order(:id).pluck(:tier)
    assert_equal [ Game::SeasonAllocationReceived ], game_events(@player).map(&:class)
    assert_not Game::SeasonAllocationPending.call(@player)
  end

  test "marking twice changes nothing more" do
    Game::MarkAllocationSeen.new.call(player: @player).value!

    assert_no_difference -> { Game::SetTier.count } do
      assert Game::MarkAllocationSeen.new.call(player: @player).success?
    end
    assert_equal 1, game_events(@player).size
  end

  test "after a trade received the allocation the recap lists the stored rows" do
    Game::ReceiveSeasonAllocation.new.call(player: @player).value!

    assert_equal %w[novice apprentice adept], Game::SeasonAllocationRecap.call(@player).received.map(&:tier)
    assert Game::SeasonAllocationPending.call(@player)
  end

  test "a player without a state row is pending, gets a recap that previews the carried tiers, and marking creates the row" do
    Game::PlayerState.where(player_id: @player.id).delete_all

    assert Game::SeasonAllocationPending.call(@player)
    recap = Game::SeasonAllocationRecap.call(@player)
    assert_equal %w[novice apprentice adept], recap.received.map(&:tier)

    assert Game::MarkAllocationSeen.new.call(player: @player).success?
    assert_equal [ 2, 2 ], [ state.allocation_received_season, state.allocation_seen_season ]
  end

  test "a null marker reads as the season before the published one" do
    Game::PlayerState.where(player_id: @player.id).update_all(allocation_seen_season: nil, allocation_received_season: nil)

    assert Game::SeasonAllocationPending.call(@player)
    assert_equal 1, Game::SeasonAllocationRecap.call(@player).ended_season_number
  end

  test "after skipped seasons the recap speaks of the season that ended, not the last one seen" do
    Catalog::Season.create!(status: :published, number: 3, published_at: 1.minute.from_now)

    assert_equal [ 3, 2 ], Game::SeasonAllocationRecap.call(@player).then { [ it.season_number, it.ended_season_number ] }
  end
end
