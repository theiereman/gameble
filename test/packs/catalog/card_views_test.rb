require "test_helper"

# Catalog::CardViews: what a card shows, for a list of card-seasons.
class Catalog::CardViewsTest < ActiveSupport::TestCase
  test "three card-seasons in French, with their years, seasons, rarities and dust" do
    portal, steel, gold = catalog_card_seasons(:portal_one), catalog_card_seasons(:steel_card_one), catalog_card_seasons(:gold_card_one)

    views = Catalog::CardViews.call([ portal.id, steel.id, gold.id, portal.id ], locale: :fr)

    assert_equal [ portal.id, steel.id, gold.id ].sort, views.keys.sort
    assert_equal Catalog::CardView.new(id: "portal", title: "Portal", publisher: "Valve", year: 2007, season_number: 1,
      rarity: "amethyst", dust: 3, image_url: "https://images.example.test/400.jpg"), views.fetch(portal.id)
    assert_equal [ "Soldat de plomb", nil, 2024, "steel", 0 ], views.fetch(steel.id).then { [ it.title, it.publisher, it.year, it.rarity, it.dust ] }
    assert_equal [ "Couronne d'or", 1998, "gold", 4 ], views.fetch(gold.id).then { [ it.title, it.year, it.rarity, it.dust ] }
    assert_equal "Golden Crown", Catalog::CardViews.call([ gold.id ], locale: "en").fetch(gold.id).title
  end

  test "a draft card-season, without rarity or dust, is left out" do
    draft_season = Catalog::Season.create!(number: 2)
    draft = Catalog::CardSeason.create!(card: catalog_cards(:portal), season: draft_season, prestige_score: 0.5, rating: 90)
    portal = catalog_card_seasons(:portal_one)

    assert_equal [ portal.id ], Catalog::CardViews.call([ draft.id, portal.id ], locale: :en).keys
    assert_equal({}, Catalog::CardViews.call([], locale: :en))
  end

  test "to_props mirrors the TypeScript CardView, in camelCase" do
    view = Catalog::CardView.new(id: "portal", title: "Portal", publisher: nil, year: 2007, season_number: 12,
      rarity: "sapphire", dust: 2, image_url: "/art.png")

    assert_equal({ id: "portal", title: "Portal", publisher: nil, year: 2007, seasonNumber: 12, rarity: "sapphire", dust: 2, imageUrl: "/art.png" },
      view.to_props)
  end

  test "one query" do
    ids = catalog_card_seasons(:portal_one, :steel_card_one, :gold_card_one).map(&:id)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { Catalog::CardViews.call(ids, locale: :en) }
    assert_equal 1, queries.size
  end
end
