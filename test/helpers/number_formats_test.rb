require "test_helper"

# The number formats of each locale (config/locales/*.yml `number`). Both
# locales define every format a view uses, so test and production (where fr
# would otherwise fall back to en) render the same characters. The French
# delimiter is a no-break space (U+00A0).
class NumberFormatsTest < ActionView::TestCase
  NBSP = " ".freeze

  test "French numbers use a no-break space between thousands and a comma before decimals" do
    I18n.with_locale(:fr) do
      assert_equal "10#{NBSP}000", number_with_delimiter(10_000)
      assert_equal "1234,500", number_with_precision(1234.5, precision: 3)
      assert_equal "12,5#{NBSP}%", number_to_percentage(12.5, precision: 1)
    end
  end

  test "English numbers keep Rails' formats" do
    I18n.with_locale(:en) do
      assert_equal "10,000", number_with_delimiter(10_000)
      assert_equal "1234.500", number_with_precision(1234.5, precision: 3)
      assert_equal "12.5%", number_to_percentage(12.5, precision: 1)
    end
  end
end
