require "test_helper"

class PresenceHelperTest < ActionView::TestCase
  Row = Game::FriendsPresence::Row

  setup { @now = Time.utc(2026, 10, 7, 15, 0) }

  def text(state, activity: nil, seen_at: nil, locale: :fr)
    I18n.with_locale(locale) { presence_text(Row.new(player: nil, state:, activity:, seen_at:), now: @now) }
  end

  test "online, an activity, and an unknown activity read as online" do
    assert_equal "En ligne", text(:online, seen_at: @now)
    assert_equal "Ouvre un booster", text(:active, activity: "opening_pack")
    assert_equal "Négocie un échange", text(:active, activity: "trading")
    assert_equal "Collecting the daily booster", text(:active, activity: "collecting_daily", locale: :en)
    assert_equal "En ligne", text(:active, activity: "retired_activity")
  end

  test "the time since last seen, in minutes, hours or days; never seen is offline" do
    assert_equal "Il y a 12 min", text(:offline, seen_at: @now - 12.minutes - 30.seconds)
    assert_equal "Il y a 1 min", text(:offline, seen_at: @now - 10.seconds)
    assert_equal "Il y a 3 h", text(:offline, seen_at: @now - 3.hours - 59.minutes)
    assert_equal "Il y a 2 j", text(:offline, seen_at: @now - 2.days - 1.hour)
    assert_equal "1 day ago", text(:offline, seen_at: @now - 1.day, locale: :en)
    assert_equal "Hors ligne", text(:offline)
    assert_equal "Offline", text(:offline, locale: :en)
  end
end
