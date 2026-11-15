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
end
