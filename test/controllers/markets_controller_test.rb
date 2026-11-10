require "test_helper"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/steam_sign_in"

class MarketsControllerTest < ActionDispatch::IntegrationTest
  include MarketListings
  include MarketSettings
  include SteamSignIn

  def open_for_good(**overrides) = open_market!(first_opened_at: 1.day.ago, **overrides)

  def tiles = css_select(".listing-tile")

  test "a visitor reads the market's plans, in French, without the players' tabs" do
    get market_path(locale: :fr)

    assert_response :success
    assert_select "h1", "La Confrérie construit le marché"
    assert_select ".market-teaser__plan", 4
    assert_select ".tab-bar", false
    assert_select "[style]", false
  end

  test "the teaser answers while no opening was ever recorded, even with the market closed" do
    Game::Market::Settings.delete_all
    close_market!

    get market_path(locale: :en)

    assert_response :success
    assert_select "h1", "The Brotherhood is building the market"
    assert_select ".market-screen", false
  end

  test "the screen replaces the teaser once a first opening is recorded, also while the market is closed again" do
    close_market!(first_opened_at: 1.day.ago)

    get market_path(locale: :en)

    assert_response :success
    assert_select "h1", "Market"
    assert_select ".market-teaser", false
    assert_select ".market-screen__empty", "No listings for now."
  end

  test "the screen shows the open listings ending soonest first, each tile one link with its accessible text" do
    open_for_good
    seller = accounts_players(:player)
    late = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), hours: 72)
    soon = listing!(seller:, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000, buy_now_price: 20_000, hours: 12,
      ends_at: 40.minutes.from_now)
    listing!(seller:, card_season: catalog_card_seasons(:uncommon_card_one), status: "sold")

    get market_path(locale: :en)

    assert_equal [ soon, late ].map { market_listing_path(locale: :en, token: it.token) }, tiles.map { it.at_css("a")["href"] }
    label = tiles.first.at_css("a")["aria-label"]
    assert_match(/\ABlue Depths, Rare, season 1, 9,000 PiCoins, 0 offers, ends at .+, buy now 20,000 PiCoins\z/, label)
    assert_select ".listing-tile:first-child .listing-tile__time.listing-tile__time--soon"
    assert_select ".listing-tile:last-child .listing-tile__time--soon", false
    assert_select ".listing-tile:first-child .listing-tile__buy-now", "Buy now"
    assert_select ".listing-tile:last-child .listing-tile__buy-now", false
    assert_select ".market-screen__empty", false
  end

  test "the sorts reorder the tiles, an unknown one falls back to ending soonest" do
    open_for_good
    seller = accounts_players(:player)
    dear = listing!(seller:, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000, hours: 72)
    cheap = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), hours: 12)

    get market_path(locale: :en, sort: "price_desc")
    assert_equal [ dear, cheap ].map(&:token), tiles.map { it.at_css("a")["href"].split("/").last }
    assert_select ".market-screen__sort[aria-current=true]", "Price, high to low"

    get market_path(locale: :en, sort: "nonsense")
    assert_equal [ cheap, dear ].map(&:token), tiles.map { it.at_css("a")["href"].split("/").last }
    assert_select ".market-screen__sort[aria-current=true]", "Ending soon"
  end

  test "Charger plus is a link to the next page, answered as a Turbo Stream that appends the tiles" do
    open_for_good
    seller = accounts_players(:player)
    25.times { listing!(seller:, card_season: catalog_card_seasons(:common_card_one)) }

    get market_path(locale: :en)
    assert_equal 24, tiles.size
    assert_select "#market-pages a.button--link[rel=next][href=?]", market_path(locale: :en, sort: "ending", page: 2), "Load more"

    get market_path(locale: :en, sort: "ending", page: 2), as: :turbo_stream
    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=append][target=market-tiles] .listing-tile", 1
    assert_select "turbo-stream[action=replace][target=market-pages]"
    assert_no_match(/rel="next"/, response.body)
  end

  test "a visitor reads the screen with CONFIER greyed and no balance chip, a player gets the link and the chip" do
    open_for_good
    get market_path(locale: :en)
    assert_select ".market-screen__chips button[disabled]", "ENTRUST CARDS"
    assert_select ".balance-chip", false

    sign_in(accounts_players(:player))
    get market_path(locale: :en)
    assert_select ".market-screen__chips a.button--secondary[href=?]", new_market_entrustment_path(locale: :en), "ENTRUST CARDS"
    assert_select ".balance-chip"
  end

  test "the screen reads in French" do
    open_for_good
    listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one))
    get market_path(locale: :fr)

    assert_select "h1", "Marché"
    assert_select ".market-screen__chip", "ANNONCES"
    assert_select ".market-screen__sort", "Se termine bientôt"
  end

  test "a GET writes nothing and no database id nor style attribute is in the markup" do
    open_for_good
    listing = listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one))

    assert_no_difference [ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.count } ] do
      get market_path(locale: :en)
    end
    assert_select "[style]", false
    assert_no_match(/(?:id|listing)[-_=:"]#{listing.id}\b/, response.body)
    assert_includes response.body, listing.token
  end

  test "a player reads it in English, inside the shell" do
    sign_in(accounts_players(:player))

    get market_path(locale: :en)

    assert_response :success
    assert_select "h1", "The Brotherhood is building the market"
    assert_select ".tab-bar"
  end

  test "the landing leads to the leaderboard beside the feed, and to the market beside the roadmap" do
    get home_path(locale: :fr)

    assert_select ".landing-live__links a.button--link[href=?]", feed_path(locale: :fr)
    assert_select ".landing-live__links a.button--link[href=?]", fortune_register_path(locale: :fr), "Voir Le Chattomètre"
    assert_select ".landing-roadmap__links a.button--link[href=?]", roadmap_path(locale: :fr)
    assert_select ".landing-roadmap__links a.button--link[href=?]", market_path(locale: :fr), "Visiter le chantier du marché"
  end
end
