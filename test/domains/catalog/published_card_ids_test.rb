require "test_helper"
require_relative "../../support/catalog_seeds"

class Catalog::PublishedCardIdsTest < ActiveSupport::TestCase
  include CatalogSeeds

  def card_in_draft_only
    season = seed_card_seasons([ 0.5 ], prefix: "draft-only")
    card_season = Catalog::CardSeason.find_by!(season:)
    card_season.update!(rarity: :rare, number: 1)
    card_season.card
  end

  def card_unrated_in_published_season
    card = Catalog::Card.create!(source_key: "src:900", release_date: Date.new(2000, 1, 1),
      image_url: "https://images.example.test/900.jpg", store_url: "https://store.example.test/900")
    Catalog::CardSeason.insert!({ card_id: card.id, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 80.0 })
    card
  end

  test "the cards of the source keys with a rated card-season in a published season, sorted, in one query" do
    portal, rare = catalog_cards(:portal), catalog_cards(:rare_card)

    ids = assert_queries_count(1) { Catalog::PublishedCardIds.call(source_keys: [ rare.source_key, portal.source_key, rare.source_key ]) }

    assert_equal [ portal.id, rare.id ].sort, ids
  end

  test "a card with a published card-season is kept once though it also has a draft one" do
    portal = catalog_cards(:portal)
    Catalog::CardSeason.create!(card: portal, season: Catalog::Season.create!(number: 2), prestige_score: 0.5, rating: 90)

    assert_equal [ portal.id ], Catalog::PublishedCardIds.call(source_keys: [ portal.source_key ])
  end

  test "a card rated in two published seasons is kept once" do
    portal, portal_one = catalog_cards(:portal), catalog_card_seasons(:portal_one)
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: portal.id, season_id: season.id, prestige_score: portal_one.prestige_score,
      rating: portal_one.rating, rarity: portal_one.rarity, number: portal_one.number } ])

    assert_equal [ portal.id ], Catalog::PublishedCardIds.call(source_keys: [ portal.source_key ])
  end

  test "a card only in a draft season or unrated in the published one is left out" do
    keys = [ card_in_draft_only.source_key, card_unrated_in_published_season.source_key ]

    assert_equal [], Catalog::PublishedCardIds.call(source_keys: keys)
  end

  test "an unknown source key is ignored" do
    assert_equal [ catalog_cards(:portal).id ], Catalog::PublishedCardIds.call(source_keys: [ "steam:999999", catalog_cards(:portal).source_key ])
  end

  test "nothing asked, no query" do
    assert_queries_count(0) { assert_equal [], Catalog::PublishedCardIds.call(source_keys: []) }
  end
end
