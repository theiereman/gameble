require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/steam_sign_in"

class Market::ListingsControllerTest < ActionDispatch::IntegrationTest
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @seller = accounts_players(:player)
    @seller.update_columns(persona_name: "Alice")
    @listing = listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 7_800, buy_now_price: 30_000,
      ends_at: (2.hours + 14.minutes + 30.seconds).from_now)
  end

  def annonce(locale: :en) = get(market_listing_path(locale:, token: @listing.token))

  test "a visitor reads the Annonce: card, seller, price, time left with the end time and the buy-now" do
    annonce

    assert_response :success
    assert_select "h1#market-listing-heading[tabindex='-1'][autofocus]", "Blue Depths"
    assert_select ".market-listing__price .picoin-amount__figure", "7,800"
    assert_select ".market-listing__price[aria-label='7,800 PiCoins']"
    assert_select ".market-listing__time", "2 h 14"
    assert_select ".market-listing__time--soon", false
    assert_select ".market-listing__ends time[datetime]"
    assert_select ".market-listing__buy-now[aria-label='30,000 PiCoins']"
    assert_select ".market-listing__fact a.player-name--linked[href=?]", brother_path(locale: :en, token: @seller.token), "Alice"
    assert_select "[data-controller~=listing-clock][data-listing-clock-seconds-value]"
    assert_select "[data-listing-clock-minutes-template-value='%{minutes} min']"
    assert_select ".balance-chip", false
  end

  test "the way back leads to the market" do
    annonce

    assert_select "a.top-bar__phone-back[href=?]", market_path(locale: :en), /Market/
  end

  test "an Annonce under an hour has the alert modifier" do
    @listing.update_columns(ends_at: 18.minutes.from_now + 30.seconds)
    annonce

    assert_select ".market-listing__time.market-listing__time--soon", "18 min"
  end

  test "the Annonce reads in French" do
    annonce(locale: :fr)

    assert_select ".market-listing__label", text: "PRIX ACTUEL"
    assert_select ".market-listing__label", text: "FIN DANS"
    assert_select ".market-listing__fact dt", text: "Vendeur"
    assert_select ".top-bar__phone-back", /Marché/
  end

  test "no buy-now means no buy-now figure, and a leader is shown" do
    @listing.update_columns(buy_now_price: nil, leader_id: accounts_players(:moderator).id, leader_maximum: 8_500, current_price: 8_000)
    annonce

    assert_select ".market-listing__buy-now", false
    assert_select ".market-listing__fact dt", text: "Leading"
    assert_select ".market-listing__price[aria-label='8,000 PiCoins']"
    assert_no_match(/8,500|8500/, response.body)
  end

  test "a private seller shows as a bare name, a banned one as the anonymous key" do
    @seller.update_columns(visibility: "private")
    sign_in(accounts_players(:moderator).tap { it.update_columns(role: "player") })
    annonce
    assert_select ".market-listing__fact span.player-name", "Alice"
    assert_select ".market-listing__fact a", false

    @seller.update_columns(banned_at: Time.current)
    annonce
    assert_select ".market-listing__fact .player-name--anonymous", "An anonymous player"
  end

  test "a player sees the balance chip" do
    sign_in(accounts_players(:administrator))
    annonce

    assert_select ".balance-chip"
  end

  test "a sold listing shows the same read-only facts" do
    @listing.update_columns(status: "sold", sold_at: Time.current, final_price: 7_800)
    annonce

    assert_response :success
    assert_select "h1", "Blue Depths"
  end

  test "an unknown token is a 404" do
    get market_listing_path(locale: :en, token: "A" * 24)

    assert_response :not_found
  end

  test "a GET writes nothing, the markup carries the token and never a database id or a style attribute" do
    assert_no_difference [ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count } ] do
      annonce
    end
    assert_select "[style]", false
    assert_no_match(/(?:id|listing)[-_=:"]#{@listing.id}\b/, response.body)
    assert_equal "/en/market/listings/#{@listing.token}", market_listing_path(locale: :en, token: @listing.token)
  end
end
