require "test_helper"

class ArchiveShopHelperTest < ActionView::TestCase
  test "a date falls back to today when the standing has no next purchase" do
    assert_equal I18n.l(Time.current.to_date, format: :day_month), archive_cap_date(nil)
    assert_equal I18n.l(Time.current.to_date, format: :day_month), archive_cap_date(Game::Market::ArchiveCaps::Standing.new(cap: 1, window_days: 1, left: 1, next_at: nil))
  end

  test "a rarity without a standing has no cap line" do
    assert_nil archive_rarity_cap_line(:common, {})
    assert_nil archive_rarity_cap_line("rare", {})
  end
end
