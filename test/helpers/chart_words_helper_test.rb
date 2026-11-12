require "test_helper"

class ChartWordsHelperTest < ActionView::TestCase
  include ChartWordsHelper
  include PicoinsHelper

  def shown_and_spoken(html)
    fragment = Nokogiri::HTML5.fragment(html)
    [ fragment.at_css("[aria-hidden=true]").text, fragment.at_css(".visually-hidden").text ]
  end

  test "a missing figure is a dash read as no value" do
    assert_equal [ "—", "no value" ], shown_and_spoken(chart_missing)
    I18n.with_locale(:fr) { assert_equal [ "—", "aucune valeur" ], shown_and_spoken(chart_picoins(nil)) }
  end

  test "a compact figure is read in full words" do
    assert_equal [ "412.6M", "412.6 million PiCoins" ], shown_and_spoken(chart_compact_picoins(412_600_000))
    assert_equal [ "31.5k", "31.5 thousand PiCoins" ], shown_and_spoken(chart_compact_picoins(31_599))
    I18n.with_locale(:fr) do
      assert_equal [ "412,6M", "412,6 millions de PiCoins" ], shown_and_spoken(chart_compact_picoins(412_600_000))
      assert_equal [ "1,5M", "1,5 million de PiCoins" ], shown_and_spoken(chart_compact_picoins(1_500_000))
      assert_equal [ "2,5 j", "2,5 jours" ], shown_and_spoken(chart_duration(2.5))
    end
    assert_equal [ "999", "999 PiCoins" ], shown_and_spoken(chart_compact_picoins(999))
  end

  test "a balance carries its sign, read as plus or minus" do
    assert_equal [ "+7,000", "plus 7,000" ], shown_and_spoken(chart_signed_picoins(7_000))
    assert_equal [ "−1,500", "minus 1,500" ], shown_and_spoken(chart_signed_picoins(-1_500))
    assert_equal "0", chart_signed_picoins(0)
    I18n.with_locale(:fr) { assert_equal "moins 1 500", shown_and_spoken(chart_signed_picoins(-1_500)).last }
  end

  test "a duration in days of capsules reads in minutes, hours or days" do
    I18n.with_locale(:fr) do
      assert_equal [ "4 min", "4 minutes" ], shown_and_spoken(chart_duration(4.0 / 1_440))
      assert_equal [ "3 h 10", "3 heures 10" ], shown_and_spoken(chart_duration(190.0 / 1_440))
      assert_equal [ "1,6 j", "1,6 jour" ], shown_and_spoken(chart_duration(1.6))
      assert_equal [ "1 min", "1 minute" ], shown_and_spoken(chart_duration(1.0 / 1_440))
    end
    assert_equal [ "2 d", "2 days" ], shown_and_spoken(chart_duration(2.0))
    assert_equal [ "1.6 d", "1.6 days" ], shown_and_spoken(chart_duration(1.6))
    assert_equal [ "1 d", "1 day" ], shown_and_spoken(chart_duration(1.0))
    assert_equal [ "1 h 05", "1 hour 05" ], shown_and_spoken(chart_duration(65.0 / 1_440))
    assert_equal [ "—", "no value" ], shown_and_spoken(chart_duration(nil))
  end

  test "a share is a percentage, its words a plain sentence part" do
    assert_equal "56%", chart_share(5_600)
    assert_equal "43.8%", chart_share_words(4_375)
    assert_equal "no value", chart_share_words(nil)
  end
end
