require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::ListingFiltersTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @seller = accounts_players(:player)
    @tin = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one), starting_price: 1_300, hours: 12)
    @hills = listing!(seller: @seller, card_season: catalog_card_seasons(:uncommon_card_one), starting_price: 3_400, hours: 24)
    @blue = listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 8_000, hours: 48)
    @portal = listing!(seller: @seller, card_season: catalog_card_seasons(:portal_one), starting_price: 25_000, hours: 72)
    catalog_card_seasons(:common_card_one).update_columns(main_theme: "roguelike")
    catalog_card_seasons(:rare_card_one).update_columns(main_theme: "roguelike")
    catalog_card_seasons(:uncommon_card_one).update_columns(main_theme: "puzzle")
  end

  def filters(viewer: nil, **params) = Game::Market::ListingFilters.from(params, genres: %w[roguelike puzzle], seasons: [ 1, 2 ], viewer:)

  def tokens(sort: "ending", locale: :en, viewer: nil, **params)
    Game::Market::OpenListings.call(sort:, page: 1, locale:, filters: filters(viewer:, **params)).rows.map(&:token)
  end

  test "with no filter every open listing is listed" do
    assert_equal [ @tin, @hills, @blue, @portal ].map(&:token), tokens
  end

  test "a search matches the title in the page's locale and the publisher, whatever the case" do
    assert_equal [ @tin.token ], tokens(q: "tin sol")
    assert_empty tokens(q: "soldat")
    assert_equal [ @tin.token ], tokens(q: "SOLDAT", locale: :fr)
    assert_equal [ @portal.token ], tokens(q: "valve")
    assert_empty tokens(q: "%")
  end

  test "rarities are an OR within the group" do
    assert_equal [ @tin, @blue ].map(&:token), tokens(rarity: %w[common rare])
    assert_equal [ @hills.token ], tokens(rarity: [ "uncommon" ])
  end

  test "genres are an OR within the group" do
    assert_equal [ @tin, @hills, @blue ].map(&:token), tokens(genre: %w[roguelike puzzle])
    assert_equal [ @hills.token ], tokens(genre: [ "puzzle" ])
  end

  test "a set keeps the listings of its cards" do
    assert_equal [ @portal.token ], tokens(sets: [ "studio:valve" ])
    assert_empty tokens(sets: [ "theme:valve" ])
  end

  test "a season keeps the listings of the editions of that season" do
    second = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    common = catalog_card_seasons(:common_card_one)
    edition = Catalog::CardSeason.insert_all!([ { card_id: common.card_id, season_id: second.id, prestige_score: 0.2, rating: 80.0, rarity: "common", number: 1 } ],
      returning: :id).rows.flatten.sole
    later = listing!(seller: @seller, card_season: Catalog::CardSeason.find(edition), starting_price: 1_300)

    assert_equal [ later.token ], tokens(season: [ "2" ])
    assert_equal [ @tin, @hills, @blue, @portal ].map(&:token), tokens(season: [ "1" ])
    assert_equal 5, tokens(season: %w[1 2]).size
  end

  test "the price range is on the current price, its ends included" do
    @blue.update_columns(current_price: 9_000)

    assert_equal [ @hills, @blue ].map(&:token), tokens(min_price: "3400", max_price: "9000")
    assert_equal [ @portal.token ], tokens(min_price: "25000")
    assert_equal [ @tin.token ], tokens(max_price: "1300")
    assert_empty tokens(min_price: "9000", max_price: "3400")
  end

  test "groups are an AND across each other" do
    assert_equal [ @blue.token ], tokens(rarity: %w[common rare], genre: [ "roguelike" ], min_price: "2000")
    assert_empty tokens(rarity: [ "epic" ], genre: [ "roguelike" ])
  end

  test "every sort keeps the filters" do
    ordered = { "ending" => [ @tin, @blue ], "price_asc" => [ @tin, @blue ], "price_desc" => [ @blue, @tin ], "newest" => [ @blue, @tin ] }

    ordered.each do |sort, listings|
      assert_equal listings.map(&:token), tokens(sort:, genre: [ "roguelike" ]), sort
    end
  end

  test "an invalid parameter is ignored" do
    assert_equal [ @tin, @hills, @blue, @portal ].map(&:token), tokens(min_price: "abc", max_price: "-5", rarity: %w[nope], genre: %w[unknown], season: %w[x 9], sets: %w[nonsense a:b])
    assert_equal [ @tin.token ], tokens(rarity: [ "common", { "x" => "y" } ])
  end

  test "the filters count their choices and name them as parameters" do
    chosen = filters(q: "tin", rarity: %w[common rare], genre: [ "puzzle" ], sets: [ "studio:valve" ], season: [ "1" ], min_price: "10", max_price: "20")

    assert_equal 7, chosen.count
    assert_equal({ q: "tin", rarity: %w[common rare], sets: [ "studio:valve" ], genre: [ "puzzle" ], season: [ 1 ], min_price: 10, max_price: 20 }, chosen.to_params)
    assert_not filters.any?
  end

  test "hiding my sales leaves out the viewer's listings and keeps everyone else's" do
    other = listing!(seller: accounts_players(:moderator), card_season: catalog_card_seasons(:common_card_one), starting_price: 2_000, hours: 6)

    assert_equal [ other.token ], tokens(viewer: @seller, hide_mine: "1")
    assert_equal [ other.token ], tokens(viewer: @seller, hide_mine: "1", rarity: [ "common" ])
    assert_equal 1, Game::Market::OpenListings.count(locale: :en, filters: filters(viewer: @seller, hide_mine: "1"))
  end

  test "hiding my sales needs a viewer and the parameter, and stays out of the filter count" do
    assert_not filters(hide_mine: "1").hides_mine?
    assert_not filters(viewer: @seller).hides_mine?
    assert_not filters(viewer: @seller, hide_mine: "yes").hides_mine?

    hidden = filters(viewer: @seller, hide_mine: "1")
    assert hidden.any?
    assert_equal 0, hidden.count
    assert_equal({ hide_mine: "1" }, hidden.to_params)
    assert_equal({ q: "tin", hide_mine: "1" }, filters(viewer: @seller, hide_mine: "1", q: "tin").to_params)
    assert_equal({ hide_mine: "1" }, filters(viewer: @seller, hide_mine: "1", q: "tin").without_query.to_params)
  end
end
