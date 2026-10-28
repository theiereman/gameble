require "test_helper"

# Catalog::CardViews: what a card shows, for a list of card-seasons.
class Catalog::CardViewsTest < ActiveSupport::TestCase
  # Gives the card-season of a published season its main theme, with
  # update_all as its season data can no longer change.
  def with_main_theme(card_season, theme)
    Catalog::CardSeason.where(id: card_season.id).update_all(main_theme: theme)
  end

  test "three card-seasons in French, with their years, seasons and rarities" do
    portal, common, legendary = catalog_card_seasons(:portal_one), catalog_card_seasons(:common_card_one), catalog_card_seasons(:legendary_card_one)

    views = Catalog::CardViews.call([ portal.id, common.id, legendary.id, portal.id ], locale: :fr)

    assert_equal [ portal.id, common.id, legendary.id ].sort, views.keys.sort
    assert_equal Catalog::CardView.new(id: "portal", title: "Portal", publisher: "Valve", year: 2007, season_number: 1,
      rarity: "epic", image_url: "https://images.example.test/400.jpg", number: 4, genre: nil), views.fetch(portal.id)
    assert_equal [ "Soldat de plomb", nil, 2024, "common" ], views.fetch(common.id).then { [ it.title, it.publisher, it.year, it.rarity ] }
    assert_equal [ "Couronne d'or", 1998, "legendary" ], views.fetch(legendary.id).then { [ it.title, it.year, it.rarity ] }
    assert_equal "Golden Crown", Catalog::CardViews.call([ legendary.id ], locale: "en").fetch(legendary.id).title
  end

  test "the number of each card-season, and its main theme as genre, nil without one" do
    portal, common = catalog_card_seasons(:portal_one), catalog_card_seasons(:common_card_one)
    with_main_theme(portal, "puzzle")

    views = Catalog::CardViews.call([ portal.id, common.id ], locale: :en)

    assert_equal [ 4, "puzzle" ], views.fetch(portal.id).then { [ it.number, it.genre ] }
    assert_equal [ 1, nil ], views.fetch(common.id).then { [ it.number, it.genre ] }, "a season published before themes"
  end

  test "the number label: the season and the number, digits grouped by three with a no-break space, no total" do
    view = ->(season_number, number) { Catalog::CardView.new(id: "x", title: "X", publisher: nil, year: 2000, season_number:,
      rarity: "common", image_url: "/art.png", number:, genre: nil) }

    assert_equal "S1 · #4\u00A0215", view.(1, 4_215).number_label
    assert_equal "S12 · #7", view.(12, 7).number_label
    assert_equal "S1 · #1\u00A0000\u00A0000", view.(1, 1_000_000).number_label
    assert_equal "S3 · #999", view.(3, 999).number_label
  end

  test "the short number label: the number alone, grouped the same way" do
    view = ->(number) { Catalog::CardView.new(id: "x", title: "X", publisher: nil, year: 2000, season_number: 12,
      rarity: "common", image_url: "/art.png", number:, genre: nil) }

    assert_equal "#4\u00A0215", view.(4_215).number_label(with_season: false)
    assert_equal "#7", view.(7).number_label(with_season: false)
  end

  test "a draft card-season, without rarity, is left out" do
    draft_season = Catalog::Season.create!(number: 2)
    draft = Catalog::CardSeason.create!(card: catalog_cards(:portal), season: draft_season, prestige_score: 0.5, rating: 90)
    portal = catalog_card_seasons(:portal_one)

    assert_equal [ portal.id ], Catalog::CardViews.call([ draft.id, portal.id ], locale: :en).keys
    assert_equal({}, Catalog::CardViews.call([], locale: :en))
  end

  test "one query" do
    ids = catalog_card_seasons(:portal_one, :common_card_one, :legendary_card_one).map(&:id)
    with_main_theme(catalog_card_seasons(:portal_one), "puzzle")

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { Catalog::CardViews.call(ids, locale: :en) }
    assert_equal 1, queries.size
  end
end
