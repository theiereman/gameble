require "test_helper"

# Steam::RawValue (story 2.11): every reader returns a valid value or a
# neutral one, never raises.
class Steam::RawValueTest < ActiveSupport::TestCase
  INT4_MAX = Steam::RawValue::INT4_MAX

  test "integer accepts an Integer or a String of digits within the range" do
    assert_equal 812, Steam::RawValue.integer(812, min: 0, max: INT4_MAX)
    assert_equal 812, Steam::RawValue.integer("812", min: 0, max: INT4_MAX)
    assert_equal 0, Steam::RawValue.integer(0, min: 0, max: 100)
    assert_equal 100, Steam::RawValue.integer("100", min: 0, max: 100)
    assert_equal INT4_MAX, Steam::RawValue.integer(INT4_MAX, min: 1, max: INT4_MAX)
  end

  test "integer gives nil for anything else" do
    [ nil, 1.0, 93.5, "1.0", "12x", "-1", " 12", "", [ 1 ], { "a" => 1 }, true, -1, 101, 2**40, "99999999999" ].each do |value|
      assert_nil Steam::RawValue.integer(value, min: 0, max: 100), value.inspect
    end
    assert_nil Steam::RawValue.integer(0, min: 1, max: INT4_MAX), "an appid starts at 1"
    assert_nil Steam::RawValue.integer(INT4_MAX + 1, min: 1, max: INT4_MAX)
    assert_nil Steam::RawValue.integer(Steam::RawValue::TIMESTAMP_MAX + 1, min: 0, max: Steam::RawValue::TIMESTAMP_MAX)
  end

  test "string removes NUL bytes from a String and gives nil for anything else" do
    assert_equal "Portal 2", Steam::RawValue.string("Por\u0000tal 2\u0000")
    assert_equal "", Steam::RawValue.string("")
    [ nil, 12, [ "a" ], { "a" => "b" } ].each { |value| assert_nil Steam::RawValue.string(value), value.inspect }
  end

  test "object returns a Hash or {}" do
    assert_equal({ "a" => 1 }, Steam::RawValue.object({ "a" => 1 }))
    [ nil, "x", [ 1 ], 3 ].each { |value| assert_equal({}, Steam::RawValue.object(value), value.inspect) }
  end

  test "string and scrub drop invalid UTF-8 bytes instead of raising" do
    bad = "Por\xFFtal\u0000 2".dup.force_encoding(Encoding::UTF_8)

    assert_equal "Portal 2", Steam::RawValue.string(bad)
    assert_equal({ "Portal 2" => [ "Portal 2" ] }, Steam::RawValue.scrub({ bad => [ bad ] }))
  end

  test "scrub removes NUL bytes from every string of a deep value, keys included" do
    raw = { "a\u0000" => [ "x\u0000y", { "b" => "\u0000" }, 1, nil, true, 1.5 ], "c" => "plain" }

    assert_equal({ "a" => [ "xy", { "b" => "" }, 1, nil, true, 1.5 ], "c" => "plain" }, Steam::RawValue.scrub(raw))
    assert_nil Steam::RawValue.scrub(nil)
  end
end
