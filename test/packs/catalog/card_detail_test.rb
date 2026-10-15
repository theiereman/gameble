require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CardDetail: a card's detail by its slug, in
# the published season or the season numbered, with its sets.
class Catalog::CardDetailTest < ActiveSupport::TestCase
  include CatalogSeeds

  # A published season numbered 2 holding portal (legendary), written with
  # insert_all as a published season can no longer change.
  def publish_season_two_with_portal
    season = seed_published_sets([])
    Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.99, rating: 99,
      rarity: Catalog::Rarity::TIERS.invert.fetch(:legendary) } ])
    season
  end

  test "a card of the published season, in two queries: its view, texts and sets" do
    portal = catalog_card_seasons(:portal_one)
    detail = nil

    assert_queries_count(2) { detail = Catalog::CardDetail.call(slug: "portal", locale: :en) }

    assert_equal Catalog::CardView.new(id: "portal", title: "Portal", publisher: "Valve", year: 2007, season_number: 1,
      rarity: "epic", image_url: "https://images.example.test/400.jpg", number: 4, genre: nil), detail.view
    assert_equal "A puzzle game of portals.", detail.short_description
    assert_equal "Valve", detail.publisher
    assert_equal "https://store.example.test/400", detail.store_url
    assert_equal [ Catalog::SetSlots::SetRef.new(kind: "studio", key: "valve", params: { "studio" => "Valve" }) ], detail.sets
    assert_equal portal.id, detail.card_season_id
    assert detail.current_season
    assert_nil detail.steam_reviews
  end

  test "a card-season's review count and share of positive reviews are its Steam reviews" do
    catalog_card_seasons(:portal_one).update_columns(review_count: 12_345, rating: 93.4)

    reviews = Catalog::CardDetail.call(slug: "portal", locale: :en).steam_reviews

    assert_equal [ 12_345, BigDecimal("93.4") ], [ reviews.count, reviews.positive_percent ]
  end

  test "in French the title and description are French" do
    assert_equal "Un jeu de casse-tête à portails.", Catalog::CardDetail.call(slug: "portal", locale: "fr").short_description
    assert_equal "Soldat de plomb", Catalog::CardDetail.call(slug: "tin-soldier", locale: "fr").view.title
  end

  test "a card without publisher, description or set has nil and none" do
    detail = Catalog::CardDetail.call(slug: "tin-soldier", locale: :en)

    assert_nil detail.publisher
    assert_nil detail.short_description
    assert_equal [], detail.sets

    catalog_card_texts(:portal_en).update_columns(short_description: "")
    detail = Catalog::CardDetail.call(slug: "portal", locale: :en)
    assert_nil detail.short_description
  end

  test "an unknown slug, a card id or a slug in another case is nothing, in one query" do
    assert_queries_count(1) { assert_nil Catalog::CardDetail.call(slug: "nope", locale: :en) }
    assert_nil Catalog::CardDetail.call(slug: catalog_cards(:portal).id.to_s, locale: :en)
    assert_nil Catalog::CardDetail.call(slug: "123", locale: :en)
    assert_nil Catalog::CardDetail.call(slug: "Portal", locale: :en)
  end

  test "without a number the published season is read; an older one by its number, not current" do
    publish_season_two_with_portal

    detail = Catalog::CardDetail.call(slug: "portal", locale: :en)
    assert_equal [ 2, "legendary", true ], [ detail.view.season_number, detail.view.rarity, detail.current_season ]
    assert_equal [], detail.sets

    older = Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 1)
    assert_equal [ 1, "epic", false ], [ older.view.season_number, older.view.rarity, older.current_season ]
    assert_equal [ "valve" ], older.sets.map(&:key)

    assert Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 2).current_season
  end

  test "a card absent from the season asked, a draft season or an unknown number is nothing" do
    publish_season_two_with_portal

    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en)
    assert Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 1)

    draft = Catalog::Season.create!(number: 3)
    Catalog::CardSeason.create!(card: catalog_cards(:common_card), season: draft, prestige_score: 0.5, rating: 90)
    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 3)
    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 9)
    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 99_999_999_999)
  end

  test "with no season published nothing is found" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_nil Catalog::CardDetail.call(slug: "portal", locale: :en)
    assert_nil Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 1)
  end

  test "the sets come themes first, then franchises, studios, the hall of fame in its fixed order and the UFOs, each by key" do
    season = seed_published_sets([
      [ "studio", "b", { "studio" => "B" } ], [ "franchise", "a", { "franchise" => "A" } ], [ "studio", "a", { "studio" => "A" } ],
      [ "ufo", "ufos", {} ], [ "theme", "rpg", { "theme" => "rpg" } ], [ "theme", "horror", { "theme" => "horror" } ],
      [ "hall_of_fame", "phenomenes", { "hall_of_fame" => "phenomenes" } ], [ "hall_of_fame", "mal-aimes", { "hall_of_fame" => "mal-aimes" } ],
      [ "hall_of_fame", "pepites", { "hall_of_fame" => "pepites" } ], [ "hall_of_fame", "intouchables", { "hall_of_fame" => "intouchables" } ]
    ])
    Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.99, rating: 99, rarity: 5 } ])
    card_season_id = Catalog::CardSeason.find_by!(season_id: season.id).id
    Catalog::SetMembership.insert_all!(Catalog::Set.where(season_id: season.id).ids.map { |set_id| { set_id:, card_season_id:, position: 1 } })

    detail = Catalog::CardDetail.call(slug: "portal", locale: :en)

    assert_equal [ [ "theme", "horror" ], [ "theme", "rpg" ], [ "franchise", "a" ], [ "studio", "a" ], [ "studio", "b" ],
      [ "hall_of_fame", "intouchables" ], [ "hall_of_fame", "pepites" ], [ "hall_of_fame", "mal-aimes" ], [ "hall_of_fame", "phenomenes" ],
      [ "ufo", "ufos" ] ],
      detail.sets.map { [ it.kind, it.key ] }
    assert_equal({ "theme" => "horror" }, detail.sets.first.params)
  end

  test "the main theme's set comes first, though its key sorts after the card's other theme" do
    season = publish_sets_draft
    card_season = Catalog::CardSeason.find_by!(season_id: season.id, main_theme: "rpg")

    detail = Catalog::CardDetail.call(slug: card_season.card.slug, locale: :en)

    assert_equal %w[rpg roguelike], card_season.card.genres
    assert_equal "rpg", detail.view.genre
    assert_equal [ [ "theme", "rpg" ], [ "theme", "roguelike" ] ], detail.sets.map { [ it.kind, it.key ] }
  end

  test "the view carries the card-season's number and its main theme as genre" do
    season = publish_sets_draft
    card_season = Catalog::Set.find_by!(season_id: season.id, kind: "theme", key: "rpg").memberships.first.card_season

    view = Catalog::CardDetail.call(slug: card_season.card.slug, locale: :en).view

    assert_equal [ card_season.number, "rpg" ], [ view.number, view.genre ]
    assert_includes 1..150, view.number
    assert_equal "S#{season.number} · ##{card_season.number}", view.number_label
  end

  test "a card-season of the UFOs has no genre" do
    season = publish_sets_draft
    card_season = Catalog::Set.find_by!(season_id: season.id, kind: "ufo", key: "ufos").memberships.first.card_season

    detail = Catalog::CardDetail.call(slug: card_season.card.slug, locale: :en)

    assert_nil detail.view.genre
    assert_equal [ [ "ufo", "ufos" ] ], detail.sets.map { [ it.kind, it.key ] }
  end

  test "a card-season of a season published before themes has no genre; one never numbered has no number" do
    publish_season_two_with_portal

    view = Catalog::CardDetail.call(slug: "portal", locale: :en).view
    assert_equal [ nil, nil, nil ], [ view.number, view.genre, view.number_label ]

    older = Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 1).view
    assert_equal [ 4, nil, "S1 · #4" ], [ older.number, older.genre, older.number_label ]
  end
end
