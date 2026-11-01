require "test_helper"

# The card-season a game shows when it is missing from a set: its card-season
# of the latest published season that rates it; and every published game's
# face as a relation, searched by title or studio, for the set editor.
class Catalog::LatestPublishedCardSeasonsTest < ActiveSupport::TestCase
  def edition(card, season, rarity: "rare")
    Catalog::CardSeason.insert_all!([ { card_id: card.id, season_id: season.id, prestige_score: 0.5, rating: 80.0, rarity:, number: rarity && card.id } ],
      returning: :id).rows.flatten.sole
  end

  test "each card's card-season of the latest published season rating it, a draft or an unrated one aside, in one query" do
    portal, rare = catalog_cards(:portal), catalog_cards(:rare_card)
    second = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    draft = Catalog::Season.create!(number: 3)
    portal_two = edition(portal, second)
    edition(portal, draft)
    edition(rare, second, rarity: nil)

    faces = assert_queries_count(1) { Catalog::LatestPublishedCardSeasons.call([ portal.id, rare.id, portal.id, -1 ]) }

    assert_equal({ portal.id => portal_two, rare.id => catalog_card_seasons(:rare_card_one).id }, faces)
  end

  test "nothing asked, no query" do
    assert_queries_count(0) { assert_equal({}, Catalog::LatestPublishedCardSeasons.call([])) }
  end

  def face_ids(...) = Catalog::LatestPublishedCardSeasons.faces(...).pluck(:id)

  test "the faces hold every published game once, on its latest published face, the latest season first then by number" do
    portal, rare = catalog_cards(:portal), catalog_cards(:rare_card)
    second = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    draft = Catalog::Season.create!(number: 3)
    portal_two = edition(portal, second)
    edition(rare, draft)
    edition(catalog_cards(:legendary_card), second, rarity: nil)

    assert_equal [ portal_two, *%i[common_card_one uncommon_card_one rare_card_one legendary_card_one].map { catalog_card_seasons(it).id } ], face_ids
  end

  test "a game rated only in an earlier published season is found on that season's face" do
    second = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    edition(catalog_cards(:portal), second)

    assert_equal [ catalog_card_seasons(:rare_card_one).id ], face_ids(query: "blue", locale: :en)
  end

  test "the search matches a title in the asked locale or a studio" do
    assert_equal [ catalog_card_seasons(:rare_card_one).id ], face_ids(query: " profondeurs ", locale: :fr)
    assert_empty face_ids(query: "profondeurs", locale: :en)
    assert_equal [ catalog_card_seasons(:portal_one).id ], face_ids(query: "valve", locale: :en)
  end

  test "picked games come in their pick order, searched too" do
    ids = %i[rare_card portal common_card].map { catalog_cards(it).id }

    assert_equal %i[rare_card_one portal_one common_card_one].map { catalog_card_seasons(it).id }, face_ids(picked: ids)
    assert_equal [ catalog_card_seasons(:common_card_one).id ], face_ids(picked: ids, query: "tin", locale: :en)
    assert_empty face_ids(picked: [])
  end
end
