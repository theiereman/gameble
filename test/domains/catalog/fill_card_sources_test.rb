require "test_helper"

# Catalog::FillCardSources: the fill of the developers, franchises and
# genres of cards, and of the review counts their card-seasons lack, from
# rows a source builds.
class Catalog::FillCardSourcesTest < ActiveSupport::TestCase
  def row(source_key, developers: [ "Valve" ], franchises: [ "Portal" ], genres: [ "puzzle" ], review_count: 1_000)
    { source_key:, developers:, franchises:, genres:, review_count: }
  end

  def fill(*rows)
    Catalog::FillCardSources.new.call(rows:)
  end

  def filled_events
    Rails.configuration.event_store.read.stream(Catalog::FillCardSources::STREAM).of_type(Catalog::CardSourcesFilled).to_a
  end

  def draft_card_season_of(card)
    draft = Catalog::Season.create!(status: :draft, number: 2)
    Catalog::CardSeason.create!(card:, season: draft, prestige_score: 0.5, rating: 90)
  end

  test "it fills a card's names and the missing review count of its card-seasons, the published one included, and publishes the counts" do
    portal = catalog_cards(:portal)
    published = catalog_card_seasons(:portal_one)
    in_draft = draft_card_season_of(portal)
    before = published.attributes.except("review_count", "updated_at")

    result = fill(row("src:400"), row("src:401", developers: [ "Studio &amp; Co" ], franchises: [], genres: [], review_count: nil))

    assert_equal({ cards: 2, card_seasons: 2 }, result.value!)
    assert_equal [ [ "Valve" ], [ "Portal" ] ], [ portal.reload.developers, portal.franchises ]
    assert_equal [ [ "Studio &amp; Co" ], [] ], [ catalog_cards(:common_card).developers, catalog_cards(:common_card).franchises ]
    assert_equal [ 1_000, 1_000 ], [ published.reload.review_count, in_draft.reload.review_count ]
    assert_equal before, published.attributes.except("review_count", "updated_at")
    assert_nil catalog_card_seasons(:common_card_one).review_count
    assert_equal [ { cards: 2, card_seasons: 2 } ], filled_events.map(&:data)
  end

  test "a second fill changes nothing and publishes zero counts" do
    fill(row("src:400"))
    updated_at = [ catalog_cards(:portal).updated_at, catalog_card_seasons(:portal_one).updated_at ]

    assert_equal({ cards: 0, card_seasons: 0 }, fill(row("src:400")).value!)

    assert_equal updated_at, [ catalog_cards(:portal).reload.updated_at, catalog_card_seasons(:portal_one).reload.updated_at ]
    assert_equal [ { cards: 1, card_seasons: 1 }, { cards: 0, card_seasons: 0 } ], filled_events.map(&:data)
  end

  test "a card's genres follow the source, its published card-season's main theme never does" do
    published = catalog_card_seasons(:portal_one)
    Catalog::CardSeason.where(id: published.id).update_all(main_theme: "puzzle")
    fill(row("src:400"))

    assert_equal({ cards: 1, card_seasons: 0 }, fill(row("src:400", genres: %w[comedy puzzle])).value!)

    assert_equal %w[comedy puzzle], catalog_cards(:portal).reload.genres
    assert_equal "puzzle", published.reload.main_theme
    assert_equal({ cards: 0, card_seasons: 0 }, fill(row("src:400", genres: %w[comedy puzzle])).value!)
    assert_equal({ cards: 1, card_seasons: 0 }, fill(row("src:400", genres: [])).value!)
    assert_equal [], catalog_cards(:portal).reload.genres
  end

  test "a card-season that has a review count keeps it; a card's names follow the source" do
    fill(row("src:400", review_count: 1_000))

    result = fill(row("src:400", developers: [ "Valve", "Nvidia" ], review_count: 9_999))

    assert_equal({ cards: 1, card_seasons: 0 }, result.value!)
    assert_equal 1_000, catalog_card_seasons(:portal_one).reload.review_count
    assert_equal [ "Valve", "Nvidia" ], catalog_cards(:portal).reload.developers
  end

  test "a row for a card that does not exist is ignored" do
    result = fill(row("src:nowhere"), row("src:400"))

    assert_equal({ cards: 1, card_seasons: 1 }, result.value!)
    assert_not Catalog::Card.exists?(source_key: "src:nowhere")
  end

  test "no rows fill nothing and still publish" do
    assert_equal({ cards: 0, card_seasons: 0 }, fill.value!)
    assert_equal 1, filled_events.size
  end

  {
    "rows that are not a list" => { "src:400" => {} },
    "a row that is not a hash" => [ "src:400" ],
    "a row missing a key" => [ { source_key: "src:400", developers: [], franchises: [], genres: [] } ],
    "a row mixing string and symbol keys" => [ { "source_key" => "src:400", developers: [], franchises: [], genres: [], review_count: nil } ],
    "a row with an unknown key" => [ { source_key: "src:400", developers: [], franchises: [], genres: [], review_count: nil, publisher: "x" } ],
    "a blank source key" => [ { source_key: " ", developers: [], franchises: [], genres: [], review_count: nil } ],
    "a developer that is not a string" => [ { source_key: "src:400", developers: [ 1 ], franchises: [], genres: [], review_count: nil } ],
    "a blank franchise" => [ { source_key: "src:400", developers: [], franchises: [ "" ], genres: [], review_count: nil } ],
    "a review count of 0" => [ { source_key: "src:400", developers: [], franchises: [], genres: [], review_count: 0 } ],
    "a genre outside the theme list" => [ { source_key: "src:400", developers: [], franchises: [], genres: [ "action" ], review_count: nil } ],
    "genres that are not a list" => [ { source_key: "src:400", developers: [], franchises: [], genres: "rpg", review_count: nil } ],
    "a review count as a string" => [ { source_key: "src:400", developers: [], franchises: [], genres: [], review_count: "10" } ]
  }.each do |label, rows|
    test "#{label} fails with invalid_card and writes nothing" do
      result = Catalog::FillCardSources.new.call(rows:)

      assert_equal :invalid_card, result.failure
      assert_equal [ [], [ "puzzle" ] ], [ catalog_cards(:portal).reload.developers, catalog_cards(:portal).genres ]
      assert_nil catalog_card_seasons(:portal_one).reload.review_count
      assert_empty filled_events
    end
  end
end
