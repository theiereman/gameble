require "test_helper"

class FeedHelperTest < ActionView::TestCase
  def entry(kind, tier: nil) = Game::FeedEntry.new(kind:, tier:)

  test "the decor behind an entry is its kind, a completed set getting a decor of its own" do
    assert_equal "pull", feed_decor(entry("pull"))
    assert_equal "sale", feed_decor(entry("sale"))
    assert_equal "set", feed_decor(entry("set", tier: "gold"))
    assert_equal "set-complete", feed_decor(entry("set", tier: Catalog::SetTier::COMPLETE))
  end
end
