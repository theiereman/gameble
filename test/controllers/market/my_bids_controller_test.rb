require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/market_auctions"
require_relative "../../support/market_bidding"

class Market::MyBidsControllerTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    open_market!(first_opened_at: 1.day.ago)
    [ @bidder, @rival ].each { fund!(it, 300_000) }
  end

  def bids(locale: :en, **params) = get(market_my_bids_path(locale:, **params))

  test "a visitor is refused with sign_in_required" do
    get market_my_bids_path(locale: :en, format: :json)

    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "a player who never bid sees the empty line and the way on, in both languages" do
    sign_in(@bidder)

    bids
    assert_response :success
    assert_select "h1", "My bids"
    assert_select ".market-screen__empty", "You have not bid on any card."
    assert_select ".market-screen__empty-state a.button--link[href=?]", market_path(locale: :en)

    bids(locale: :fr)
    assert_select ".market-screen__empty", "Vous n'avez enchéri sur aucune carte."
  end

  test "three auctions each appear once with their status word, price, own maximum and group" do
    leading = listing!(seller: @seller, card_season: @common, starting_price: 20_000)
    outbid = listing!(seller: @seller, card_season: @rare, starting_price: 20_000, hours: 30)
    ended = listing!(seller: @seller, card_season: @uncommon, status: "unsold", ends_at: 1.day.ago)
    assert bid(@bidder, 30_000, leading).success?
    assert bid(@rival, 90_000, outbid).success?
    assert bid(@bidder, 40_000, outbid).success?
    Game::Market::Bid.create!(listing: ended, player: @bidder, maximum: 25_000, price_after: 1_300, outcome: "lost")
    sign_in(@bidder)

    bids

    assert_select "section[aria-labelledby=my-bids-in-progress-heading] .market-row", 2
    assert_select "section[aria-labelledby=my-bids-recent-heading] .market-row", 1
    assert_select "#my-bids-recent-heading", "FINISHED RECENTLY"
    assert_select ".market-row__chip", text: "LEADING"
    assert_select ".market-row__chip", text: "OUTBID"
    assert_select ".market-row__chip", text: "LOST"
    assert_select "[data-row-token=?]", leading.token, 1
    assert_select ".market-row__fact dt", text: "My maximum", count: 3
    assert_select ".market-row__fact dd .picoin-amount[aria-label=?]", "30,000 PiCoins"
    assert_select ".market-row__fact dd .picoin-amount[aria-label=?]", "40,000 PiCoins"
    assert_select ".market-screen__chip--current[aria-current=page]", "MY BIDS"
    assert_no_match(/90,000|90000/, response.body)
  end

  test "RELEVER is filled only when outbid, named with the card and links with the focus parameter, and ended rows have none" do
    leading = listing!(seller: @seller, card_season: @common, starting_price: 20_000)
    outbid = listing!(seller: @seller, card_season: @rare, starting_price: 20_000, hours: 30)
    ended = listing!(seller: @seller, card_season: @uncommon, status: "unsold", ends_at: 1.day.ago)
    assert bid(@bidder, 30_000, leading).success?
    assert bid(@rival, 90_000, outbid).success?
    assert bid(@bidder, 40_000, outbid).success?
    Game::Market::Bid.create!(listing: ended, player: @bidder, maximum: 25_000, price_after: 1_300, outcome: "lost")
    sign_in(@bidder)

    bids

    assert_select "a.button--primary[href=?][aria-label=?]", market_listing_path(locale: :en, token: outbid.token, focus: "maximum"), "Raise, Blue Depths", "RAISE"
    assert_select "a.button--secondary[href=?][aria-label=?]", market_listing_path(locale: :en, token: leading.token, focus: "maximum"), "Raise, Tin Soldier"
    assert_select "section[aria-labelledby=my-bids-recent-heading] .market-row__action", false
  end

  test "RELEVER reads in French" do
    outbid = listing!(seller: @seller, card_season: @rare, starting_price: 20_000)
    assert bid(@rival, 90_000, outbid).success?
    assert bid(@bidder, 40_000, outbid).success?
    sign_in(@bidder)

    bids(locale: :fr)

    assert_select ".market-row__chip", text: "DÉPASSÉ"
    assert_select "a.button--primary[aria-label=?]", "Relever, Profondeurs bleues", "RELEVER"
    assert_select ".market-row__fact dt", text: "Mon maximum"
  end

  test "a due open row says the close is under way and has no action" do
    due = listing!(seller: @seller, card_season: @rare, ends_at: 1.minute.ago)
    Game::Market::Bid.create!(listing: due, player: @bidder, maximum: 25_000, price_after: 1_300, outcome: "beaten")
    sign_in(@bidder)

    bids

    assert_select ".market-row__fact dd", text: "Closing…"
    assert_select ".market-row__action", false
  end

  test "the chips on the market screen include MES ENCHÈRES, greyed for a visitor and a link for a player" do
    get market_path(locale: :en)
    assert_select "span.market-screen__chip--disabled[aria-disabled=true]", "MY BIDS"

    sign_in(@bidder)
    get market_path(locale: :en)
    assert_select "a.market-screen__chip[href=?]", market_my_bids_path(locale: :en), "MY BIDS"
    assert_equal %w[LISTINGS MY\ BIDS MY\ SALES], css_select(".market-screen__chips .market-screen__chip").map { it.text.strip }
  end

  test "a GET writes nothing, and no database id, leader maximum or style attribute is in the page" do
    listing = listing!(seller: @seller, card_season: @common, starting_price: 20_000)
    assert bid(@rival, 77_777, listing).success?
    assert bid(@bidder, 30_000, listing).success?
    sign_in(@bidder)

    assert_no_difference [ -> { Game::Market::Bid.count }, -> { Game::Market::LedgerEntry.count } ] do
      bids
    end

    assert_select "[style]", false
    assert_no_match(/(?:id|listing)[-_=:"]#{listing.id}\b/, response.body)
    assert_no_match(/77,777|77777/, response.body)
  end

  test "a suspended market draws the banner and disables RELEVER on every row" do
    outbid = listing!(seller: @seller, card_season: @rare, starting_price: 20_000)
    assert bid(@rival, 90_000, outbid).success?
    assert bid(@bidder, 40_000, outbid).success?
    Game::Market::Settings.delete_all
    close_market!(first_opened_at: 1.day.ago)
    sign_in(@bidder)

    bids

    assert_select "#market-suspended-banner", 1
    assert_select "button[disabled][aria-describedby=market-suspended-banner][aria-label=?]", "Raise, Blue Depths", "RAISE"
    assert_select "a.button[aria-label=?]", "Raise, Blue Depths", false
    assert_select ".market-row__title[data-row-token=?]", outbid.token
  end
end
