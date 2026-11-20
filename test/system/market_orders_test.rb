require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"

class MarketOrdersSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include MarketAuctions
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def available(amount) = ".balance-chip--bar .balance-chip__available[aria-label='#{amount} PiCoins']"

  def committed(text) = assert_selector(".balance-chip--bar .balance-chip__committed .visually-hidden", text:, visible: :all)

  test "a player places an order from the card detail, finds it under MY ORDERS and cancels it free" do
    sign_in_through_the_site(@player)

    visit card_path(locale: :en, slug: "tin-soldier")
    find("a.button--primary", text: /place an order/i).click

    assert_selector "h1#order-form-heading", text: "Tin Soldier"
    assert_selector ".order-form__sentence", text: "Commons from 13."
    fill_in "order-price", with: "300"
    assert_selector ".order-reach__chip--reached", count: 4
    assert_selector ".order-form__sentence", text: "Your price reaches commons, uncommons, rares, and epics. Legendaries from 70,000."
    assert_selector ".order-form__submit", text: /300/
    find(".order-form__submit").click

    assert_selector "#order-result-heading:focus", text: "ORDER PLACED ON Tin Soldier"
    assert_selector "section[aria-labelledby=my-orders-in-progress-heading] .market-row", text: "Tin Soldier"
    assert_selector available(700)
    committed("300 committed")

    find("button[aria-label='Cancel the order, Tin Soldier']").click
    order = Game::Market::Order.sole
    assert_selector "dialog#cancel-order-#{order.token}[open] h2:focus", text: "CANCEL THIS ORDER?"
    within("dialog#cancel-order-#{order.token}") { click_button "CANCEL THE ORDER" }

    assert_text "Order cancelled: your 300 PiCoins are returned to you."
    assert_selector ".empty-state__line", text: "You have placed no order."
    assert_no_selector ".market-row"
    assert_selector available("1,000")
    committed("0 committed")
  end

  test "a visitor sees MY ORDERS greyed and is led to the landing from the form" do
    visit market_path(locale: :en)
    assert_selector ".market-screen__chips .tabs__tab--disabled", text: "MY ORDERS"

    visit new_market_card_order_path(locale: :en, slug: "tin-soldier")
    assert_current_path home_path(locale: :en)
  end
end
