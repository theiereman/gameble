require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_snapshots"

class Game::Market::EconomyAlertsTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketSnapshots

  setup do
    clear_snapshots
    @now = Time.utc(2026, 11, 10, 8)
    @last_day = Date.new(2026, 11, 9)
  end

  def alerts(settings) = Game::Market::EconomyAlerts.call(Game::Market::EconomySeries.call(now: @now, settings:), settings)

  def alert(name, settings) = alerts(settings).find { it.indicator == name }

  test "a destroyed share under its threshold proposes the Rare stamp raised by half, with the minimum up to the floor" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000)
    snapshot!(@last_day, created: 100, destroyed_total: 34)

    found = alert(:destroyed_share, settings)

    assert_equal [ 3_400, 4_000 ], [ found.value, found.threshold ]
    assert_equal({ stamp_rare: 30, minimum_price_rare: 89 }, found.changes)
    assert_equal({ stamp_rare: 20, minimum_price_rare: 78 }, found.current)
    assert found.actionable?
  end

  test "a share at its threshold, or over it, raises no alert" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000)
    snapshot!(@last_day, created: 100, destroyed_total: 40)

    assert_empty alerts(settings)
  end

  test "PiCoins per player above their threshold propose the same Rare stamp change" do
    settings = open_market!(alert_picoins_per_player: 100)
    snapshot!(@last_day, picoins_per_active_player: 120)

    assert_equal({ stamp_rare: 30, minimum_price_rare: 89 }, alert(:picoins_per_player, settings).changes)
  end

  test "a top share above its threshold proposes the Legendary stamp raised by half, its minimum staying above the floor" do
    settings = open_market!(alert_top_share_basis_points: 3_000)
    snapshot!(@last_day, top_share_basis_points: 3_500)

    assert_equal({ stamp_legendary: 150 }, alert(:top_share, settings).changes)
  end

  test "a null point raises no alert" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000, alert_picoins_per_player: 1, alert_top_share_basis_points: 1)
    snapshot!(@last_day, created: 0, destroyed_total: 0)

    assert_empty alerts(settings)
  end

  test "a blank threshold raises no alert" do
    settings = open_market!(alert_destroyed_share_basis_points: nil, alert_picoins_per_player: nil, alert_top_share_basis_points: nil)
    snapshot!(@last_day, created: 10_000, destroyed_total: 0, picoins_per_active_player: 9_999_999, top_share_basis_points: 9_999)

    assert_empty alerts(settings)
  end

  test "days of income raises no alert, whatever its target" do
    settings = open_market!(income_days_target_epic: BigDecimal("0.1"))
    snapshot!(@last_day, average_price_epic: 9_000, median_daily_earnings: 10)

    assert_empty alerts(settings)
  end

  test "no settings raises no alert" do
    assert_empty Game::Market::EconomyAlerts.call(Game::Market::EconomySeries.call(now: @now, settings: nil), nil)
  end

  test "a proposed stamp never passes double the current one" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000, stamp_rare: 1, minimum_price_rare: 78, entrustment_rare: 25)
    snapshot!(@last_day, created: 100, destroyed_total: 1)

    assert_equal 2, alert(:destroyed_share, settings).changes.fetch(:stamp_rare)
  end

  test "every proposal passes the settings rules" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000, alert_picoins_per_player: 1, alert_top_share_basis_points: 1)
    snapshot!(@last_day, created: 10_000, destroyed_total: 100, picoins_per_active_player: 5, top_share_basis_points: 9_000)
    rules = Game::Market::SettingsRules.new(settings)

    alerts(settings).each do |found|
      candidate = settings.attributes.symbolize_keys.slice(*Game::Market::SettingsRules::EDITABLE).merge(found.changes)
      assert_empty rules.violations(candidate)
    end
  end

  test "a proposed minimum over the Archive price raises the Archive price to it, and the candidate passes the rules" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000, archive_price_rare: 80)
    snapshot!(@last_day, created: 100, destroyed_total: 34)

    found = alert(:destroyed_share, settings)

    assert_equal({ stamp_rare: 30, minimum_price_rare: 89, archive_price_rare: 89 }, found.changes)
    candidate = settings.attributes.symbolize_keys.slice(*Game::Market::SettingsRules::EDITABLE).merge(found.changes)
    assert_empty Game::Market::SettingsRules.new(settings).violations(candidate)
  end

  test "an Archive price at or above the proposed minimum, or not set, is left alone" do
    snapshot!(@last_day, created: 100, destroyed_total: 34)

    [ 89, 500, nil ].each do |archive_price|
      settings = open_market!(alert_destroyed_share_basis_points: 4_000, archive_price_rare: archive_price)

      assert_equal({ stamp_rare: 30, minimum_price_rare: 89 }, alert(:destroyed_share, settings).changes, archive_price.inspect)
    end
  end

  test "a proposal the bounds refuse leaves the alert without an action" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000, stamp_rare: 2_000, minimum_price_rare: 5_000, entrustment_rare: 5_000,
      commission_basis_points: 2_500)
    snapshot!(@last_day, created: 100, destroyed_total: 1)

    found = alert(:destroyed_share, settings)

    assert_empty found.changes
    assert_not found.actionable?
  end

  test "named finds an alert by its indicator's name and nothing else" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000)
    snapshot!(@last_day, created: 100, destroyed_total: 1)
    series = Game::Market::EconomySeries.call(now: @now, settings:)

    assert_equal :destroyed_share, Game::Market::EconomyAlerts.named("destroyed_share", series, settings).indicator
    assert_nil Game::Market::EconomyAlerts.named("top_share", series, settings)
    assert_nil Game::Market::EconomyAlerts.named("nothing", series, settings)
  end
end
