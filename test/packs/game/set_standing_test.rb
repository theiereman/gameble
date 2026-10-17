require "test_helper"

class Game::SetStandingTest < ActiveSupport::TestCase
  test "a measured set reads its tier from its counts, never as just reached" do
    standing = Game::SetStanding.measured(set_id: 1, held: 5, total: 16, tiers: { "bronze" => 2, "silver" => 4, "gold" => 8, "complete" => 16 })

    assert_equal "silver", standing.reached_tier
    assert_equal [ true, true, false ], %w[bronze silver gold].map { standing.tier_reached?(it) }
    assert_not standing.complete?
    assert_not standing.just
    assert_not standing.reached_now
    assert Game::SetStanding.measured(set_id: 1, held: 3, total: 3, tiers: { "complete" => 3 }).complete?
  end
end
