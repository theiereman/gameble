require "test_helper"
require_relative "../../support/second_season"

class Game::CardBacksEarnedInTest < ActiveSupport::TestCase
  include SecondSeason

  setup do
    @player = accounts_players(:player)
    @second, @set = publish_second_season(@player)
    @first = Catalog::Season.find_by!(number: 1)
    @first.update!(published_at: 10.days.ago)
    @second.update!(published_at: 1.hour.ago)
  end

  def earned_keys(before: @second.published_at)
    Game::CardBacksEarnedIn.call(@player, @first, before:).map { it.back.key }
  end

  test "the backs unlocked during the season come in unlock order, with their unlock time" do
    Game::CardBackUnlock.record(@player.id, Game::CardBacks::GOAL_BACK, 3.days.ago)
    Game::CardBackUnlock.record(@player.id, Game::CardBacks.set_key("theme", "horror"), 5.days.ago)

    earned = Game::CardBacksEarnedIn.call(@player, @first, before: @second.published_at)

    assert_equal [ Game::CardBacks.set_key("theme", "horror"), Game::CardBacks::GOAL_BACK ], earned.map { it.back.key }
    assert_in_delta 5.days.ago, earned.first.unlocked_at, 5
  end

  test "a back unlocked before the season began or after it ended is left out" do
    Game::CardBackUnlock.record(@player.id, Game::CardBacks::GOAL_BACK, 20.days.ago)
    Game::CardBackUnlock.record(@player.id, Game::CardBacks.set_key("theme", "horror"), 30.minutes.ago)

    assert_empty earned_keys
  end

  test "another player's unlocks and keys outside the catalogue are left out" do
    Game::CardBackUnlock.record(accounts_players(:administrator).id, Game::CardBacks::GOAL_BACK, 3.days.ago)
    Game::CardBackUnlock.record(@player.id, "retired-back", 3.days.ago)

    assert_empty earned_keys
  end

  test "the recap carries the backs earned in the ended season" do
    Game::CardBackUnlock.record(@player.id, Game::CardBacks::GOAL_BACK, 3.days.ago)

    assert_equal [ Game::CardBacks::GOAL_BACK ], Game::SeasonAllocationRecap.call(@player).backs.map { it.back.key }
  end
end
