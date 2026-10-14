require "test_helper"

# The name of a page's locale in its link previews.
class CardDetailsHelperTest < ActionView::TestCase
  test "og_locale names each served locale as Open Graph does" do
    assert_equal "en_US", I18n.with_locale(:en) { og_locale }
    assert_equal "fr_FR", I18n.with_locale(:fr) { og_locale }
  end

  test "every served locale has an Open Graph name, so one cannot be added without it" do
    assert_equal I18n.available_locales.map(&:to_s).sort, CardDetailsHelper::OG_LOCALES.keys.sort
  end

  test "a locale without an Open Graph name keeps its own code" do
    assert_equal "de", og_locale_for("de")
  end

  test "a card detail link includes the card year in English" do
    view = Catalog::CardView.new(id: "hades", title: "Hades", publisher: nil, year: 2020, season_number: 2,
      rarity: "epic", image_url: "/art.png", number: nil, genre: nil)

    I18n.with_locale(:en) do
      assert_equal "Hades, 2020, Epic, season 2", card_detail_open_label(view, CardStrings.new)
    end
  end

  test "a card detail link includes the card year in French" do
    view = Catalog::CardView.new(id: "hades", title: "Hadès", publisher: nil, year: 2020, season_number: 2,
      rarity: "epic", image_url: "/art.png", number: nil, genre: nil)

    I18n.with_locale(:fr) do
      assert_equal "Hadès, 2020, Épique, saison 2", card_detail_open_label(view, CardStrings.new)
    end
  end
end
