require "test_helper"

# Game::DuelProfiles reads the stored duel profiles, the five stats in their fixed order.
class Game::DuelProfilesTest < ActiveSupport::TestCase
  test "a computed card-season's profile, its stats in order and its trump; a card-season without a row has none" do
    now = Time.current.change(usec: 0)
    Game::ComputeDuelStats.new.call(reason: "first", now:).value!
    portal = catalog_card_seasons(:portal_one).id

    profiles = Game::DuelProfiles.call([ portal, -1 ])

    assert_equal [ portal ], profiles.keys
    profile = profiles.fetch(portal)
    assert_equal %i[popularity rating release discovery circulation], profile.stats.map(&:name)
    assert_equal now, profile.computed_at
    assert_equal 95, profile.stats.second.value
    assert_not profile.stats.first.value?
    assert profile.stats.second.value?
    assert_equal profile.trump_stat, profile.trump.name
    assert_includes %w[high low], profile.trump_direction
  end

  test "a stat moved since last Monday by 5 points or more, either way; with no weekly or current percentile it did not move" do
    risen = stat(BigDecimal("62.0"), BigDecimal("55.0"))

    assert_equal [ 7, true ], [ risen.weekly_move, risen.moved? ]
    assert stat(BigDecimal("50.0"), BigDecimal("55.0")).moved?
    assert_not stat(BigDecimal("59.9"), BigDecimal("55.0")).moved?
    assert_equal [ nil, false ], [ stat(BigDecimal("62.0"), nil).weekly_move, stat(BigDecimal("62.0"), nil).moved? ]
    assert_not stat(nil, BigDecimal("55.0")).moved?
  end

  private
    def stat(percentile, weekly_percentile)
      Game::DuelProfiles::Stat.new(name: :popularity, value: 1, percentile:, median_distance: 0.0, weekly_percentile:)
    end
end
