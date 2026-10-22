require "test_helper"

class CardDetailsHelperTest < ActionView::TestCase
  test "a card detail link includes the card year in English" do
    view = Catalog::CardView.new(id: "hades", title: "Hades", publisher: nil, year: 2020, season_number: 2,
      rarity: "epic", image_url: "/art.png", number: nil, genre: nil)

    I18n.with_locale(:en) do
      assert_equal "Hades, 2020, Epic, season 2", card_detail_open_label(view, CardStrings.new)
    end
  end

  test "only epic and legendary are top rarities" do
    assert card_top_rarity?("epic")
    assert card_top_rarity?("legendary")
    assert_not card_top_rarity?("rare")
    assert_not card_top_rarity?("uncommon")
    assert_not card_top_rarity?("common")
  end

  test "rays render only for top rarities, with their colour class" do
    assert_match(/card-rays card-rays--epic/, card_rays("epic").to_s)
    assert_match(/card-rays card-rays--legendary/, card_rays("legendary").to_s)
    assert_nil card_rays("rare")
    assert_nil card_rays("common")
  end

  test "a card detail link includes the card year in French" do
    view = Catalog::CardView.new(id: "hades", title: "Hadès", publisher: nil, year: 2020, season_number: 2,
      rarity: "epic", image_url: "/art.png", number: nil, genre: nil)

    I18n.with_locale(:fr) do
      assert_equal "Hadès, 2020, Épique, saison 2", card_detail_open_label(view, CardStrings.new)
    end
  end
end
