require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/holdings"

class Game::BestCardsTest < ActiveSupport::TestCase
  include Holdings
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @common, @uncommon, @rare, @epic, @legendary = fixture_tier_ids
  end

  test "the rarest held cards first, the latest gained first within a rarity, in one query" do
    hold(@player, @common, gained_at: 1.minute.ago)
    hold(@player, @rare, gained_at: 3.hours.ago)
    hold(@player, @legendary, gained_at: 2.days.ago)
    hold(@player, @epic, gained_at: 1.hour.ago)

    result = nil
    assert_queries_count(1) { result = Game::BestCards.call(@player, limit: 3) }
    assert_equal [ @legendary, @epic, @rare ], result
  end

  test "cards traded away or set aside are left out" do
    hold(@player, @legendary, 0, gained_at: 1.minute.ago)
    hold(@player, @epic, gained_at: 1.hour.ago)
    hold(@player, @rare, gained_at: 1.hour.ago)

    assert_equal [ @rare ], Game::BestCards.call(@player, limit: 5, except: [ @epic ])
  end

  test "nothing, without a query, for a visitor or no room left" do
    hold(@player, @epic, gained_at: 1.hour.ago)

    assert_queries_count(0) do
      assert_empty Game::BestCards.call(nil, limit: 5)
      assert_empty Game::BestCards.call(@player, limit: 0)
    end
  end
end
