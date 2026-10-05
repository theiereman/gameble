require "test_helper"

# Catalog::CardViews: what a card shows, for a list of card-seasons.
class Catalog::CardViewsTest < ActiveSupport::TestCase
  # Puts the card-season in a tome of genre `genre` of its (published)
  # season, with insert_all as a published season's sets can no longer change.
  def in_tome(card_season, genre)
    set_id = Catalog::Set.insert_all!([ { season_id: card_season.season_id, kind: "tome", key: "#{genre}-1",
      params: { "genre" => genre, "volume" => 1, "volumes" => 1 } } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!([ { set_id:, card_season_id: card_season.id, position: 1 } ])
  end

  test "three card-seasons in French, with their years, seasons, rarities and dust" do
    portal, common, legendary = catalog_card_seasons(:portal_one), catalog_card_seasons(:common_card_one), catalog_card_seasons(:legendary_card_one)

    views = Catalog::CardViews.call([ portal.id, common.id, legendary.id, portal.id ], locale: :fr)

    assert_equal [ portal.id, common.id, legendary.id ].sort, views.keys.sort
    assert_equal Catalog::CardView.new(id: "portal", title: "Portal", publisher: "Valve", year: 2007, season_number: 1,
      rarity: "epic", dust: 3, image_url: "https://images.example.test/400.jpg", number: 4, genre: nil), views.fetch(portal.id)
    assert_equal [ "Soldat de plomb", nil, 2024, "common", 0 ], views.fetch(common.id).then { [ it.title, it.publisher, it.year, it.rarity, it.dust ] }
    assert_equal [ "Couronne d'or", 1998, "legendary", 4 ], views.fetch(legendary.id).then { [ it.title, it.year, it.rarity, it.dust ] }
    assert_equal "Golden Crown", Catalog::CardViews.call([ legendary.id ], locale: "en").fetch(legendary.id).title
  end

  test "the number of each card-season, and the genre of its tome, nil when in no tome" do
    portal, common = catalog_card_seasons(:portal_one), catalog_card_seasons(:common_card_one)
    in_tome(portal, "puzzle")

    views = Catalog::CardViews.call([ portal.id, common.id ], locale: :en)

    assert_equal [ 4, "puzzle" ], views.fetch(portal.id).then { [ it.number, it.genre ] }
    assert_equal [ 1, nil ], views.fetch(common.id).then { [ it.number, it.genre ] }, "in the publisher set only"
  end

  test "an unnumbered card-season has no number and no label" do
    common = catalog_card_seasons(:common_card_one)
    Catalog::CardSeason.where(id: common.id).update_all(number: nil)

    view = Catalog::CardViews.call([ common.id ], locale: :en).fetch(common.id)
    assert_nil view.number
    assert_nil view.number_label
  end

  test "the number label: the season and the number, digits grouped by three with a no-break space, no total" do
    view = ->(season_number, number) { Catalog::CardView.new(id: "x", title: "X", publisher: nil, year: 2000, season_number:,
      rarity: "common", dust: 0, image_url: "/art.png", number:, genre: nil) }

    assert_equal "S1 · #4\u00A0215", view.(1, 4_215).number_label
    assert_equal "S12 · #7", view.(12, 7).number_label
    assert_equal "S1 · #1\u00A0000\u00A0000", view.(1, 1_000_000).number_label
    assert_equal "S3 · #999", view.(3, 999).number_label
    assert_nil view.(1, nil).number_label
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
      rarity: "rare", dust: 2, image_url: "/art.png", number: 4_215, genre: "puzzle")

    assert_equal({ id: "portal", title: "Portal", publisher: nil, year: 2007, seasonNumber: 12, rarity: "rare", dust: 2, imageUrl: "/art.png",
      number: 4_215, genre: "puzzle" }, view.to_props)
  end

  test "one query" do
    ids = catalog_card_seasons(:portal_one, :common_card_one, :legendary_card_one).map(&:id)
    in_tome(catalog_card_seasons(:portal_one), "puzzle")

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { Catalog::CardViews.call(ids, locale: :en) }
    assert_equal 1, queries.size
  end
end
