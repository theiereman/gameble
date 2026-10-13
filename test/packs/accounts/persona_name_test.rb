require "test_helper"

# A Steam persona name made fit to show (CAP-8; epic 4 retrospective B4):
# invisible characters dropped, spaces made plain and squished, cut to 64
# graphemes, and nil when nothing visible remains. Every character other
# than ASCII is written as a \u escape.
class Accounts::PersonaNameTest < ActiveSupport::TestCase
  def clean(value) = Accounts::PersonaName.clean(value)

  test "a plain name is kept" do
    assert_equal "Gabe the Brave", clean("Gabe the Brave")
    assert_equal "Gab\u00E9 \u2605 42!", clean("Gab\u00E9 \u2605 42!")
    assert_equal "\u30B2\u30FC\u30D6", clean("\u30B2\u30FC\u30D6")
  end

  [ nil, 42, :gabe, [ "Gabe" ] ].each do |value|
    test "#{value.inspect}, not a string, is no name" do
      assert_nil clean(value)
    end
  end

  # Zero-width space, right-to-left override, Hangul filler, left-to-right
  # isolate, ideographic space, blank Braille pattern, variation selector 16,
  # soft hyphen, word joiner, Mongolian vowel separator, controls, line
  # separator.
  [ "", "   ", "\u200B", "\u200B\u202E", "\u3164", "\u2066 \u3000", "\u2800\u2800", "\uFE0F", "\u00AD", "\u2060\u180E",
    "\u0000\n\t", "\u2028" ].each do |value|
    test "#{value.inspect}, nothing visible, is no name" do
      assert_nil clean(value)
    end
  end

  {
    "Ga\u200Bbe" => "Gabe",
    "\u202Egabe" => "gabe",
    "gabe\u2066" => "gabe",
    "A\u3000B" => "A B",
    "A\u00A0\u00A0B" => "A B",
    "  Ga\u0000be\n " => "Gabe",
    "Ga\u3164be" => "Gabe",
    "\u2800Gabe\u2800" => "Gabe"
  }.each do |value, cleaned|
    test "#{value.inspect} is cleaned to #{cleaned.inspect}" do
      assert_equal cleaned, clean(value)
    end
  end

  test "a long name is cut to 64 graphemes, then stripped" do
    assert_equal "a" * 64, clean("  #{"a" * 70}  ")
    assert_equal "a" * 63, clean("#{"a" * 63} b")
    assert_equal "a" * 64, clean("\u200B" * 10 + "a" * 70)
  end

  ACCENTED = "e\u0301\u0302"
  THUMBS_UP = "\u{1F44D}\u{1F3FD}"
  FLAG = "\u{1F1EB}\u{1F1F7}"

  [ ACCENTED, THUMBS_UP, FLAG ].each do |grapheme|
    test "a long name ending in #{grapheme.inspect} is cut after a whole one" do
      assert_equal "a" * 63 + grapheme, clean("a" * 63 + grapheme * 2)
    end
  end

  test "a long name of combining marks, modified emoji and flags is cut to 64 whole graphemes" do
    cleaned = clean((ACCENTED + THUMBS_UP + FLAG) * 22)

    assert_equal 64, cleaned.grapheme_clusters.size
    assert_equal (ACCENTED + THUMBS_UP + FLAG) * 21 + ACCENTED, cleaned
  end

  [ ACCENTED * 64, FLAG * 64, (ACCENTED + THUMBS_UP + FLAG) * 21 + ACCENTED ].each do |name|
    test "#{name.grapheme_clusters.size} graphemes in #{name.length} code points are kept" do
      assert_equal name, clean(name)
    end
  end

  test "bytes that are not UTF-8 are dropped; a UTF-8 name tagged binary keeps its characters" do
    assert_equal "Gabe", clean("Ga\xFFbe")
    assert_nil clean("\xFF".b)
    assert_equal "Gab\u00E9", clean("Gab\u00E9".b)
  end
end
