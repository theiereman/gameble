require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_listings"
require_relative "../support/steam_sign_in"

class MarketsControllerTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketAuctions
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

  test "a visitor reads the screen with both actions greyed and no balance chip, a player gets the links and the chip" do
    open_for_good
    get market_path(locale: :en)
    assert_select ".market-screen__actions button[disabled]", 2
    assert_select ".market-screen__actions button[disabled][aria-label=?]", "ENTRUST CARDS"
    assert_select ".market-screen__actions button[disabled][aria-label=?]", "PUT UP FOR SALE"
    assert_select ".balance-chip", false

    sign_in(accounts_players(:player))
    get market_path(locale: :en)
    assert_select ".market-screen__actions a.button--secondary[href=?][aria-label=?]", new_market_entrustment_path(locale: :en), "ENTRUST CARDS" do
      assert_select ".market-screen__long", "ENTRUST CARDS"
      assert_select ".market-screen__short", "ENTRUST"
    end
    assert_select ".market-screen__actions a.button--primary[href=?][aria-label=?]", new_market_sale_path(locale: :en), "PUT UP FOR SALE" do
      assert_select ".market-screen__long", "PUT UP FOR SALE"
      assert_select ".market-screen__short", "SELL"
    end
    assert_select ".balance-chip"
  end

  test "while the market is suspended the sale action is disabled for a player" do
    Game::Market::Settings.delete_all
    close_market!(first_opened_at: 2.days.ago)
    sign_in(accounts_players(:player))

    get market_path(locale: :en)

    assert_select ".market-screen__actions button[disabled][aria-label=?]", "PUT UP FOR SALE"
    assert_select ".market-screen__actions a[href=?]", new_market_sale_path(locale: :en), false
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

  test "a suspended market draws the banner above the chips and disables both actions with the banner as their reason" do
    Game::Market::Settings.delete_all
    close_market!(first_opened_at: 2.days.ago)
    listing = listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one))
    sign_in(accounts_players(:player))

    get market_path(locale: :en)

    assert_select "#market-suspended-banner[role=status]", 1
    assert_select ".market-desk ~ #market-suspended-banner ~ .market-screen__bar .market-screen__chips"
    assert_select ".market-screen__actions button[disabled][aria-describedby=market-suspended-banner]", 2
    assert_select ".market-screen__actions a.button", false
    assert_select ".listing-tile a[href=?]", market_listing_path(locale: :en, token: listing.token)
    assert_select "a.market-screen__chip[href=?]", market_my_sales_path(locale: :en)
    assert_select "a.market-screen__chip[href=?]", market_my_bids_path(locale: :en)
  end

  test "a suspended market reads the same for a visitor, with the chips greyed" do
    Game::Market::Settings.delete_all
    close_market!(first_opened_at: 2.days.ago)

    get market_path(locale: :en)

    assert_select "#market-suspended-banner", 1
    assert_select ".market-screen__actions button[disabled][aria-describedby=market-suspended-banner]", 2
    assert_select ".market-screen__chip--disabled[aria-disabled=true]", 2
  end

  test "an open market and a never opened one draw no banner" do
    Game::Market::Settings.delete_all
    open_for_good
    get market_path(locale: :en)
    assert_select "#market-suspended-banner", false
    assert_select ".market-screen__actions [aria-describedby]", false

    Game::Market::Settings.delete_all
    close_market!
    get market_path(locale: :en)
    assert_select ".market-teaser"
    assert_select "#market-suspended-banner", false
  end

  test "a player's counter holds the purse and the way to their bids and sales, with the outbid count first" do
    open_for_good
    player = accounts_players(:player)
    fund!(player, 12_000)
    listing!(seller: player, card_season: catalog_card_seasons(:common_card_one))
    sign_in(player)

    get market_path(locale: :en)

    assert_select ".market-desk h1#market-screen-heading", "Market"
    assert_select ".market-desk__available .picoin-amount__figure", "12,000"
    assert_select ".market-mine a.market-mine__item[href=?]", market_my_bids_path(locale: :en), 2
    assert_select ".market-mine a.market-mine__item[href=?]", market_my_sales_path(locale: :en), /1\s+sale in progress/
    assert_select ".market-mine__item--alert", false
    assert_select ".market-welcome", false
  end

  test "a player with nothing on the market yet is welcomed with the count of their spare copies" do
    open_for_good
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:common_card_one).id, 3)
    sign_in(player)

    get market_path(locale: :en)

    assert_select ".market-welcome a.button[href=?]", new_market_entrustment_path(locale: :en)
    assert_select ".market-welcome__note", "You have 2 spare copies."
    assert_select ".market-mine", false
  end

  test "the listings ending within the hour get a row of their own above the rest" do
    open_for_good
    soon = listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one), ends_at: 20.minutes.from_now)
    listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:rare_card_one), hours: 24)

    get market_path(locale: :en)

    assert_select ".market-soon__link[href=?]", market_listing_path(locale: :en, token: soon.token), 1
    assert_select ".market-soon ~ .market-screen__section", /2/
    assert_select ".listing-tile__link--soon", 1
  end

  test "a search that finds nobody names the game and offers to clear the search, keeping the sort" do
    open_for_good
    listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one))

    get market_path(locale: :en, q: "Zork", sort: "newest")

    assert_select ".market-empty__title", "Nobody is selling “Zork”"
    assert_select ".market-empty a.button[href=?]", market_path(locale: :en, sort: "newest")
    assert_select ".market-soon", false
  end
end
