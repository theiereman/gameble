require "test_helper"
require_relative "../../../support/market"

class Game::Market::PublishedRulesTest < ActiveSupport::TestCase
  include MarketSettings

  setup { Game::Market::Settings.delete_all }

  test "no settings version publishes nothing" do
    assert_nil Game::Market::PublishedRules.call
  end

  test "a version that never opened publishes nothing" do
    open_market!(open: false, first_opened_at: nil)

    assert_nil Game::Market::PublishedRules.call
  end

  test "a version that opened publishes its starting values" do
    open_market!(first_opened_at: Time.current)

    rules = Game::Market::PublishedRules.call
    starting = Game::Market::StartingSettings::ATTRIBUTES

    assert_equal %i[common uncommon rare epic legendary], rules.entrustment.keys
    assert_equal starting[:entrustment_rare], rules.entrustment[:rare]
    assert_equal starting[:stamp_epic], rules.stamp[:epic]
    assert_equal starting[:minimum_price_legendary], rules.minimum_price[:legendary]
    assert_equal starting[:commission_basis_points], rules.commission_basis_points
    assert_equal starting[:daily_cap], rules.daily_cap
    assert_equal [ 12, 24, 72 ], rules.durations
    assert_equal starting[:preselected_duration_hours], rules.preselected_hours
    assert_equal starting[:increment_basis_points], rules.increment_basis_points
    assert_equal starting[:soft_close_seconds], rules.soft_close_seconds
    assert_equal starting[:unusual_maximum_multiple], rules.unusual_maximum_multiple
  end

  test "a newer version publishes its own values" do
    open_market!(first_opened_at: Time.current)
    open_market!(first_opened_at: Time.current, commission_basis_points: 750, increment_basis_points: 300)

    rules = Game::Market::PublishedRules.call

    assert_equal 750, rules.commission_basis_points
    assert_equal 300, rules.increment_basis_points
  end

  test "a closed market that opened once still publishes its rules" do
    open_market!(first_opened_at: 1.day.ago)
    close_market!(first_opened_at: 1.day.ago)

    assert_not_nil Game::Market::PublishedRules.call
  end
end
