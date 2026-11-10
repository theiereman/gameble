require "test_helper"

class PicoinsHelperTest < ActionView::TestCase
  FORMS = JSON.parse(file_fixture("picoin_forms.json").read)

  test "every form of the shared fixture reads the same as on the client" do
    FORMS.each do |row|
      I18n.with_locale(row["locale"]) do
        assert_equal row["text"], picoins(row["amount"], compact: row["compact"]), row.inspect
      end
    end
  end

  test "an amount that is not a whole non-negative number is refused" do
    [ 1.5, "12x", nil, -1, "-1" ].each do |bad|
      assert_raises(ArgumentError, bad.inspect) { picoins(bad) }
    end
  end

  test "a string of digits is read as that amount" do
    assert_equal "12", picoins("12")
  end
end
