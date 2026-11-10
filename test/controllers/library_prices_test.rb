require "test_helper"
require_relative "../support/library_requests"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

class LibraryPricesTest < ActionDispatch::IntegrationTest
  include LibraryRequests
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    price!(:common_card_one, 1_000, 5)
    price!(:uncommon_card_one, 4_000, 3)
    price!(:rare_card_one, 9_000, 2)
    price!(:portal_one, 30_000, 5)
  end

  def price!(name, average, sales)
    Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(name).id, average:, sales_used: sales)
  end

  def titles = css_select(".collection-slot .card__title").map(&:text)

  def prices = css_select(".collection-slot__price").map { it.text.squish }

  test "descending puts the dearest first and the cards with no sale last, each with its price" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, sort: "price_desc")

    assert_equal [ "Portal", "Blue Depths", "Green Hills", "Tin Soldier", "Golden Crown" ], titles
    assert_equal [ "30k", "9k few sales", "4k", "1k", "No sale" ], prices
  end

  test "ascending keeps the cards with no sale last" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, sort: "price_asc")

    assert_equal [ "Tin Soldier", "Green Hills", "Blue Depths", "Portal", "Golden Crown" ], titles
  end

  test "a range keeps the cards inside it with their prices under them" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, min_price: "4000", max_price: "9000")

    assert_equal [ "Green Hills", "Blue Depths" ].sort, titles.sort
    assert_equal 2, prices.size
    assert_select "[data-collection-filters-target=pastilleCount][data-groups=price] [data-pastille-number]", "2"
    assert_select "input[name=min_price][value='4000']"
    assert_select "input[name=max_price][value='9000']"
  end

  test "a card's accessible name ends with the price state" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, sort: "price_desc")

    labels = css_select(".collection-slot a.card-link").map { it["aria-label"] }
    assert labels.first.end_with?("average price 30,000 PiCoins")
    assert labels.second.end_with?("average price 9,000 PiCoins, few sales")
    assert labels.last.end_with?("no sale")
  end

  test "no price shows without the sort or the filter" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en)

    assert_select ".collection-slot__price", false
    assert_select ".collection-slot a.card-link[aria-label*=average]", false
  end

  test "the PRIX group offers the order and the two bounds, and the pastille counts them" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, sort: "price_asc", max_price: "5000")

    assert_select ".price-group[data-group=price] input[type=radio][name=sort]", 3
    assert_select ".price-group input[name=sort][value=price_asc][checked]"
    assert_select ".price-group input[name=min_price]"
    assert_select "[data-collection-filters-target=pastilleCount][data-groups=price] [data-pastille-number]", "2"
  end

  test "the cards' links carry the price parameters into their detail's grid" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, sort: "price_desc", min_price: "500")

    link = css_select(".collection-slot a.card-link").first["href"]
    assert_includes link, "grid%5Bsort%5D=price_desc"
    assert_includes link, "grid%5Bmin_price%5D=500"
  end

  test "a visitor can sort too" do
    get library_cards_path(locale: :en, sort: "price_desc")

    assert_equal "Portal", titles.first
    assert_equal 5, prices.size
  end

  test "an invalid order or amount is ignored" do
    sign_in(accounts_players(:moderator))

    get library_cards_path(locale: :en, sort: "up", min_price: "abc")

    assert_response :success
    assert_select ".collection-slot__price", false
  end

  test "before the first opening the group, the pastille and the parameters are absent" do
    Game::Market::Settings.delete_all
    open_market!
    sign_in(accounts_players(:moderator))
    get library_cards_path(locale: :en)
    usual = titles

    get library_cards_path(locale: :en, sort: "price_desc", min_price: "100")

    assert_select ".price-group", false
    assert_select "input[name=min_price]", false
    assert_select ".collection-slot__price", false
    assert_equal usual, titles
  end

  test "a GET writes nothing" do
    sign_in(accounts_players(:moderator))

    assert_no_difference -> { Game::Market::EditionPrice.count + Game::Market::LedgerEntry.count } do
      get library_cards_path(locale: :en, sort: "price_desc")
    end
  end
end
