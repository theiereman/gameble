require "test_helper"
require_relative "../support/market"
require_relative "../support/market_listings"

# The market screen's search, its FILTRES panel and its price group, carried through the sorts and "Charger plus".
class MarketFiltersTest < ActionDispatch::IntegrationTest
  include MarketListings
  include MarketSettings

  setup do
    open_market!(first_opened_at: 1.day.ago)
    seller = accounts_players(:player)
    @tin = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), starting_price: 1_300, hours: 12)
    @blue = listing!(seller:, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000, hours: 72)
    catalog_card_seasons(:rare_card_one).update_columns(main_theme: "roguelike")
  end

  def tokens = css_select(".listing-tile").map { it.at_css("a")["href"].split("/").last }

  test "the screen draws the search, the folded filters with every group and the two price fields" do
    get market_path(locale: :en)

    assert_response :success
    assert_select "form.market-filters[role=search][method=get]" do
      assert_select "input[type=search][name=q]"
      assert_select "details.filters__zone:not([open])"
      assert_select "fieldset[data-group=rarity] input[name='rarity[]']", 5
      assert_select "fieldset[data-group=genre] input[name='genre[]'][value=roguelike]"
      assert_select "fieldset[data-group=season] input[name='season[]'][value='1']"
      assert_select "fieldset[data-group=price] label", text: /Minimum price/
      assert_select "fieldset[data-group=price] label", text: /Maximum price/
      assert_select "fieldset[data-group=price] input[type=number]", 2
    end
    assert_select ".filters__count:not([hidden])", 0
  end

  test "the filters narrow the tiles, open the panel with their count and keep what was typed" do
    get market_path(locale: :en, rarity: [ "rare" ], min_price: "5000", max_price: "20000", q: "blue")

    assert_equal [ @blue.token ], tokens
    assert_select "details.filters__zone[open]"
    assert_select ".filters__count", text: /3/
    assert_select "input[name=q][value=blue]"
    assert_select "input[name='rarity[]'][value=rare][checked]"
    assert_select "input[name=min_price][value='5000']"
    assert_select "input[name=max_price][value='20000']"
  end

  test "the sorts and Charger plus carry the filters" do
    25.times { listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:rare_card_one)) }

    get market_path(locale: :en, rarity: [ "rare" ], genre: [ "roguelike" ], sort: "price_asc")

    assert_equal 24, tokens.size
    assert_select ".market-screen__sort[href*='rarity%5B%5D=rare'][href*='genre%5B%5D=roguelike']", 4
    assert_select "#market-pages a[rel=next][href*='rarity%5B%5D=rare'][href*='page=2'][href*='sort=price_asc']"
    assert_select "input[name=sort][value=price_asc]"

    get market_path(locale: :en, rarity: [ "rare" ], genre: [ "roguelike" ], sort: "price_asc", page: 2), as: :turbo_stream
    assert_select "turbo-stream[action=append][target=market-tiles] .listing-tile", 2
  end

  test "a filter with no match says so, in French and English, and no filter keeps the usual line" do
    get market_path(locale: :en, rarity: [ "epic" ])
    assert_select ".market-screen__empty", "No listings match these filters."

    get market_path(locale: :fr, rarity: [ "epic" ])
    assert_select ".market-screen__empty", "Aucune annonce ne correspond à ces filtres."

    Game::Market::Listing.delete_all
    get market_path(locale: :en)
    assert_select ".market-screen__empty", "No listings for now."
  end

  test "an invalid parameter is ignored and the whole list shows" do
    get market_path(locale: :en, rarity: [ "nope" ], min_price: "abc", season: [ "x" ], sets: [ "junk" ], genre: { a: "b" })

    assert_response :success
    assert_equal [ @tin, @blue ].map(&:token), tokens
    assert_select "details.filters__zone:not([open])"
  end

  test "the screen reads in French" do
    get market_path(locale: :fr)

    assert_select "fieldset[data-group=price] legend", "Prix"
    assert_select "fieldset[data-group=price] label", text: /Prix minimum/
    assert_select "input[name=q][placeholder=?]", "Rechercher un jeu"
  end

  test "a GET writes nothing and the markup holds no style attribute" do
    assert_no_difference -> { Game::Market::Listing.count + Rails.configuration.event_store.read.count } do
      get market_path(locale: :en, rarity: [ "rare" ])
    end
    assert_select "[style]", false
  end
end
