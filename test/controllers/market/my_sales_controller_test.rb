require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_listings"

class Market::MySalesControllerTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    @seller = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    open_market!(first_opened_at: 1.day.ago)
  end

  def sales(locale: :en, **params) = get(market_my_sales_path(locale:, **params))

  test "a visitor is refused with sign_in_required" do
    get market_my_sales_path(locale: :en, format: :json)

    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "a seller with no listing sees the empty line and the way on" do
    sign_in(@seller)

    sales

    assert_response :success
    assert_select "h1", "My sales"
    assert_select ".market-screen__empty", "You have not put any card up for sale."
    assert_select ".market-screen__empty-state a.button--link[href=?]", new_market_sale_path(locale: :en), "PUT UP FOR SALE"
    assert_select ".market-row", false
  end

  test "the empty line reads in French" do
    sign_in(@seller)

    sales(locale: :fr)

    assert_select ".market-screen__empty", "Vous n'avez mis aucune carte en vente."
  end

  test "rows come in two groups with status words, and the chips mark MES VENTES as current" do
    open = listing!(seller: @seller, card_season: @common, starting_price: 2_000)
    unsold = listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 1.day.ago)
    sign_in(@seller)

    sales

    assert_select "#my-sales-in-progress-heading[tabindex='-1']", "IN PROGRESS"
    assert_select "#my-sales-ended-heading[tabindex='-1']", "FINISHED"
    assert_select "section[aria-labelledby=my-sales-in-progress-heading] .market-row", 1
    assert_select "section[aria-labelledby=my-sales-ended-heading] .market-row", 1
    assert_select ".market-row__chip", text: "IN PROGRESS"
    assert_select ".market-row__chip", text: "NO BID"
    assert_select ".market-row__title[href=?]", market_listing_path(locale: :en, token: open.token)
    assert_select ".market-row__note", /No bid, the card is returned. The stamp is not refunded./
    assert_select ".market-screen__chip--current[aria-current=page]", "MY SALES"
    assert_select "a.market-screen__chip[href=?]", market_path(locale: :en), "LISTINGS"
    assert_select "[data-row-token=?]", unsold.token
  end

  test "ANNULER shows only on a cancellable row, with its dialog" do
    free = listing!(seller: @seller, card_season: @common)
    led = listing!(seller: @seller, card_season: @rare)
    led.update_columns(leader_id: accounts_players(:moderator).id, leader_maximum: 30_000)
    sign_in(@seller)

    sales

    assert_select "button[aria-label=?]", "Cancel the sale, Tin Soldier", 1
    assert_select "button[aria-label=?]", "Cancel the sale, Blue Depths", 0
    assert_select "dialog#cancel-#{free.token}", 1
    assert_select "dialog#cancel-#{led.token}", 0
    assert_select "dialog#cancel-#{free.token} h2[autofocus]", "CANCEL THIS SALE?"
    assert_select "dialog#cancel-#{free.token} form[action=?]", market_listing_cancellation_path(locale: :en, token: free.token)
    assert_select "dialog#cancel-#{free.token} input[name=return_to][value=sales]"
    assert_select "dialog#cancel-#{free.token} input[name=landing][value=?]", led.token
    assert_select "dialog#cancel-#{free.token} button", text: "KEEP THE SALE"
    assert_select "dialog#cancel-#{free.token} button", text: "CANCEL THE SALE"
    assert_select "[data-dialog-opener-dialog-value=?]", "cancel-#{free.token}", 1
  end

  test "an unsold row with a free copy offers REMETTRE EN VENTE with the amounts prefilled" do
    hold(@seller, @rare.id, 1)
    listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 1.day.ago, starting_price: 9_000, buy_now_price: 20_000)
    sign_in(@seller)

    sales

    ref = "#{@rare.card.slug}:#{@rare.season.number}"
    assert_select "a.button[href=?]", new_market_sale_path(locale: :en, ref:, start: 9_000, buy_now: 20_000, relisting: 1), "PUT UP FOR SALE AGAIN"
    assert_select "a.button[aria-label=?]", "Put up for sale again, Blue Depths"
  end

  test "the landing is written as a value, and absent when there is none" do
    sign_in(@seller)
    listing!(seller: @seller, card_season: @common)

    sales(landing: "ABC")
    assert_select "[data-controller=row-focus][data-row-focus-landing-value=ABC]"

    sales(landing: "")
    assert_select "[data-controller=row-focus][data-row-focus-landing-value='']"

    sales
    assert_select "[data-controller=row-focus]:not([data-row-focus-landing-value])"
  end

  test "the market screen draws the chips: links for a player, greyed for a visitor" do
    get market_path(locale: :en)
    assert_select "span.market-screen__chip--disabled[aria-disabled=true]", "MY SALES"
    assert_select "a[href=?]", market_my_sales_path(locale: :en), false

    sign_in(@seller)
    get market_path(locale: :en)
    assert_select "a.market-screen__chip[href=?]", market_my_sales_path(locale: :en), "MY SALES"
    assert_select ".market-screen__chip--current[aria-current=page]", "LISTINGS"
  end

  test "a GET writes nothing, and no database id or style attribute is in the page" do
    listing = listing!(seller: @seller, card_season: @common)
    sign_in(@seller)

    assert_no_difference [ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.count } ] do
      sales
    end

    assert_select "[style]", false
    assert_no_match(/(?:id|listing)[-_=:"]#{listing.id}\b/, response.body)
    assert_includes response.body, listing.token
  end

  test "a suspended market draws the banner, keeps ANNULER and disables REMETTRE EN VENTE" do
    hold(@seller, @rare.id, 1)
    open_listing = listing!(seller: @seller, card_season: @common)
    listing!(seller: @seller, card_season: @rare, status: "unsold", ends_at: 1.day.ago)
    close_market!(first_opened_at: 1.day.ago)
    sign_in(@seller)

    sales

    assert_select "#market-suspended-banner", 1
    assert_select "button[disabled][aria-describedby=market-suspended-banner][aria-label=?]", "Put up for sale again, Blue Depths"
    assert_select "a.button[href*=?]", "/market/sell", false
    assert_select "button[aria-label=?]:not([disabled])", "Cancel the sale, Tin Soldier"
    assert_select "dialog#cancel-#{open_listing.token}"
  end

  test "an open market draws no banner" do
    sign_in(@seller)

    sales

    assert_select "#market-suspended-banner", false
  end
end
