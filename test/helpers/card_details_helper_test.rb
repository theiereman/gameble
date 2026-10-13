require "test_helper"

# The words and links of a card's detail and of the links leading to it
# (with what it browses: a grid, an opened pack, a set), its faded card
# back, and its link previews.
class CardDetailsHelperTest < ActionView::TestCase
  test "og_locale names each served locale as Open Graph does" do
    assert_equal "en_US", I18n.with_locale(:en) { og_locale }
    assert_equal "fr_FR", I18n.with_locale(:fr) { og_locale }
  end

  test "every served locale has an Open Graph name, so one cannot be added without it" do
    assert_equal I18n.available_locales.map(&:to_s).sort, CardDetailsHelper::OG_LOCALES.keys.sort
  end

  test "a locale without an Open Graph name keeps its own code" do
    I18n.available_locales += [ :de ]
    assert_equal "de", I18n.with_locale(:de) { og_locale }
  ensure
    I18n.available_locales -= [ :de ]
  end
end
