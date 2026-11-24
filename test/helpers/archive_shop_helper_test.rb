require "test_helper"

class ArchiveShopHelperTest < ActionView::TestCase
  include LocalTimeHelper

  REOPENS = Time.utc(2026, 10, 15, 23, 30)

  def reached = { rare: Game::Market::ArchiveCaps::Standing.new(cap: 1, window_days: 1, left: 0, next_at: REOPENS) }

  test "a date falls back to now when the standing has no next purchase" do
    freeze_time do
      assert_equal local_time_text(Time.current), archive_cap_date(nil)
      assert_equal local_time_text(Time.current), archive_cap_date(Game::Market::ArchiveCaps::Standing.new(cap: 1, window_days: 1, left: 1, next_at: nil))
    end
  end

  test "a rarity without a standing has no cap line" do
    assert_nil archive_rarity_cap_line(:common, {})
    assert_nil archive_rarity_cap_line("rare", {})
    assert_nil archive_rarity_cap_text(:common, {})
  end

  test "the reached cap line wraps the instant in a time tag, with a UTC text without the viewer's zone" do
    render inline: archive_rarity_cap_line(:rare, reached)

    assert_select "time[datetime='2026-10-15T23:30:00Z'][data-controller='local-time']", "2026-10-15 23:30 UTC"
    assert_equal "1 Rare per day · next on 2026-10-15 23:30 UTC", archive_rarity_cap_text(:rare, reached)
  end

  test "the reached cap line reads in the viewer's time zone, in the tag and in the plain text" do
    request.set_header("HTTP_COOKIE", "time_zone=Pacific%2FAuckland")

    render inline: archive_rarity_cap_line(:rare, reached)

    assert_select "time[datetime='2026-10-15T23:30:00Z']", "Oct 16, 12:30"
    assert_equal "1 Rare per day · next on Oct 16, 12:30", archive_rarity_cap_text(:rare, reached)
    assert_equal "Oct 16, 12:30", archive_cap_date(reached.fetch(:rare))
  end
end
