require "test_helper"

# Catalog::CardSeasonLabels: a drawn card's title in a locale and its rarity.
class Catalog::CardSeasonLabelsTest < ActiveSupport::TestCase
  test "titles in the locale asked, rarity names, one entry per card-season" do
    portal, gold = catalog_card_seasons(:portal_one), catalog_card_seasons(:gold_card_one)

    assert_equal({ portal.id => { title: "Portal", rarity: :amethyst }, gold.id => { title: "Couronne d'or", rarity: :gold } },
      Catalog::CardSeasonLabels.call([ portal.id, gold.id, portal.id ], locale: :fr))
    assert_equal "Golden Crown", Catalog::CardSeasonLabels.call([ gold.id ], locale: "en").fetch(gold.id)[:title]
    assert_equal({}, Catalog::CardSeasonLabels.call([], locale: :en))
  end
end
