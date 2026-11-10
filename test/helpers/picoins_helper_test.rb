require "test_helper"

class PicoinsHelperTest < ActionView::TestCase
  test "the exact form groups thousands by the page's language" do
    assert_equal "1,234,567", picoins(1_234_567)
    I18n.with_locale(:fr) { assert_equal "1 234 567", picoins(1_234_567) }
    assert_equal "0", picoins(0)
    assert_equal "999", picoins(999)
  end

  test "the compact form starts at a thousand and truncates to one decimal, never rounding up" do
    assert_equal "999", picoins(999, compact: true)
    assert_equal "1k", picoins(1_000, compact: true)
    assert_equal "31.5k", picoins(31_599, compact: true)
    assert_equal "999.9k", picoins(999_999, compact: true)
    assert_equal "1M", picoins(1_000_000, compact: true)
    assert_equal "7.2M", picoins(7_299_999, compact: true)
    assert_equal "1,200M", picoins(1_200_000_000, compact: true)
  end

  test "the compact form uses the decimal comma in French" do
    I18n.with_locale(:fr) do
      assert_equal "31,5k", picoins(31_599, compact: true)
      assert_equal "7,2M", picoins(7_299_999, compact: true)
    end
  end
end
