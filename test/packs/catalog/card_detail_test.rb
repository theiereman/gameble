require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CardDetail (CAP-7, story 4.3): a card's detail by its slug, in
# the published season or the season numbered, with its sets.
class Catalog::CardDetailTest < ActiveSupport::TestCase
  include CatalogSeeds

  # A published season numbered 2 holding portal (gold, buried), written
  # with insert_all as a published season can no longer change.
  def publish_season_two_with_portal
    season = seed_published_sets([])
    Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.99, rating: 99,
      rarity: Catalog::Rarity::TIERS.invert.fetch(:gold), dust_tier: Catalog::Dust::LEVELS.invert.fetch(:buried) } ])
    season
  end

  test "a card of the published season, in two queries: its view, texts, credits and sets" do
    portal = catalog_card_seasons(:portal_one)
    catalog_cards(:portal).update_columns(credit: "© Valve Corporation.\nAll rights reserved.")
    detail = nil

    assert_queries_count(2) { detail = Catalog::CardDetail.call(slug: "portal", locale: :en) }

    assert_equal Catalog::CardView.new(id: "portal", title: "Portal", publisher: "Valve", year: 2007, season_number: 1,
      rarity: "amethyst", dust: 3, image_url: "https://images.example.test/400.jpg"), detail.view
    assert_equal "A puzzle game of portals.", detail.short_description
    assert_equal "Valve", detail.publisher
    assert_equal "© Valve Corporation.\nAll rights reserved.", detail.credit
    assert_equal "https://store.example.test/400", detail.store_url
    assert_equal [ Catalog::SetSlots::SetRef.new(kind: "publisher", key: "valve", params: { "publisher" => "Valve" }) ], detail.sets
    assert_equal portal.id, detail.card_season_id
    assert detail.current_season
  end

  test "in French the title and description are French" do
    assert_equal "Un jeu de casse-tête à portails.", Catalog::CardDetail.call(slug: "portal", locale: "fr").short_description
    assert_equal "Soldat de plomb", Catalog::CardDetail.call(slug: "tin-soldier", locale: "fr").view.title
  end

  test "a card without publisher, credit, description or set has nil and none" do
    detail = Catalog::CardDetail.call(slug: "tin-soldier", locale: :en)

    assert_nil detail.publisher
    assert_nil detail.credit
    assert_nil detail.short_description
    assert_equal [], detail.sets

    catalog_card_texts(:portal_en).update_columns(short_description: "")
    catalog_cards(:portal).update_columns(credit: "")
    detail = Catalog::CardDetail.call(slug: "portal", locale: :en)
    assert_nil detail.short_description
    assert_nil detail.credit
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
    assert_equal [ 2, "gold", 4, true ], [ detail.view.season_number, detail.view.rarity, detail.view.dust, detail.current_season ]
    assert_equal [], detail.sets

    older = Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 1)
    assert_equal [ 1, "amethyst", 3, false ], [ older.view.season_number, older.view.rarity, older.view.dust, older.current_season ]
    assert_equal [ "valve" ], older.sets.map(&:key)

    assert Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 2).current_season
  end

  test "a card absent from the season asked, a draft season or an unknown number is nothing" do
    publish_season_two_with_portal

    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en)
    assert Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 1)

    draft = Catalog::Season.create!(number: 3)
    Catalog::CardSeason.create!(card: catalog_cards(:steel_card), season: draft, prestige_score: 0.5, rating: 90)
    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 3)
    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 9)
    assert_nil Catalog::CardDetail.call(slug: "tin-soldier", locale: :en, season_number: 99_999_999_999)
  end

  test "with no season published nothing is found" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_nil Catalog::CardDetail.call(slug: "portal", locale: :en)
    assert_nil Catalog::CardDetail.call(slug: "portal", locale: :en, season_number: 1)
  end

  test "the sets come tome first, then publisher, then best of year, each by key" do
    season = publish_sets_draft
    id = Catalog::SetMembership.joins(:set).where(catalog_sets: { season_id: season.id, kind: "publisher", key: "p" }).pick(:card_season_id)
    slug = Catalog::CardSeason.find(id).card.slug
    expected = Catalog::Set.joins(:memberships).where(catalog_set_memberships: { card_season_id: id }).pluck(:kind, :key)
      .sort_by { |kind, key| [ %w[tome publisher best_of_year].index(kind), key ] }

    detail = Catalog::CardDetail.call(slug:, locale: :en)

    assert_equal expected, detail.sets.map { [ it.kind, it.key ] }
    assert_includes detail.sets.map(&:kind), "tome"
    assert_equal "publisher", detail.sets.find { it.key == "p" }.kind
    assert_equal({ "publisher" => "P" }, detail.sets.find { it.key == "p" }.params)
  end
end
