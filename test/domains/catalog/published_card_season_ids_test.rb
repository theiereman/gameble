require "test_helper"

class Catalog::PublishedCardSeasonIdsTest < ActiveSupport::TestCase
  test "the published card-season of each slug and season number, in one query" do
    portal, legendary = catalog_card_seasons(:portal_one), catalog_card_seasons(:legendary_card_one)
    pairs = [ [ "portal", 1 ], [ legendary.card.slug, 1 ], [ "portal", 1 ] ]

    ids = assert_queries_count(1) { Catalog::PublishedCardSeasonIds.call(pairs) }

    assert_equal({ [ "portal", 1 ] => portal.id, [ legendary.card.slug, 1 ] => legendary.id }, ids)
  end

  test "an unknown slug or season is left out" do
    assert_equal({}, Catalog::PublishedCardSeasonIds.call([ [ "portal", 7 ], [ "no-such-card", 1 ] ]))
  end

  test "a card-season of a draft season is left out" do
    draft_season = Catalog::Season.create!(number: 2)
    Catalog::CardSeason.create!(card: catalog_cards(:portal), season: draft_season, prestige_score: 0.5, rating: 90)

    assert_equal [ [ "portal", 1 ] ], Catalog::PublishedCardSeasonIds.call([ [ "portal", 1 ], [ "portal", 2 ] ]).keys
  end

  test "nothing asked, no query" do
    assert_queries_count(0) { assert_equal({}, Catalog::PublishedCardSeasonIds.call([])) }
  end
end
