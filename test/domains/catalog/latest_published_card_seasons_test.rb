require "test_helper"

# The card-season a game shows when it is missing from a set: its card-season
# of the latest published season that rates it.
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
end
