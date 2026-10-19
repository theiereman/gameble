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

  test "a ranked set's thresholds go by the count each tier asks, whatever its name" do
    standing = Game::SetStanding.measured(set_id: 1, held: 31, total: 62, tiers: Catalog::TierTable.tiers(62))

    assert_equal [ [ "apprentice", 7 ], [ "adept", 16 ], [ "expert", 31 ], [ "master", 47 ], [ "complete", 62 ] ], standing.thresholds
    assert_equal "expert", standing.reached_tier
    assert_equal [ "master", 16 ], [ standing.next_tier, standing.missing ]
    assert standing.tier_reached?("adept")
    assert_not standing.tier_reached?("master")
  end

  test "equal counts of an earlier season's metals keep their metal order" do
    standing = Game::SetStanding.measured(set_id: 1, held: 1, total: 3, tiers: { "silver" => 1, "gold" => 2, "bronze" => 1, "complete" => 3 })

    assert_equal %w[bronze silver gold complete], standing.thresholds.map(&:first)
    assert_equal "silver", standing.reached_tier
  end

  test "a set of 7 has a tier before completion, a set of 3 has none" do
    seven = Game::SetStanding.unstarted(set_id: 1, total: 7, tiers: Catalog::TierTable.tiers(7))
    three = Game::SetStanding.unstarted(set_id: 2, total: 3, tiers: Catalog::TierTable.tiers(3))

    assert_predicate seven, :tiered?
    assert_equal [ "master", 4 ], [ seven.next_tier, seven.next_required ]
    assert_not three.tiered?
    assert_equal [ [ "complete", 3 ] ], three.thresholds
  end
end
