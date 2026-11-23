require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/holdings"

class MarketOrdersSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketOrders
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

  def recent_rows = "section[aria-labelledby=my-orders-recent-heading] .market-row"

  def serve!(order, card_season)
    seller = accounts_players(:moderator).tap { it.update!(persona_name: "Ada") }
    fund!(seller, 1_000)
    hold(seller, card_season.id, 1)
    Game::Market::SellToOrder.new.call(player: seller, card_season_id: card_season.id, order_token: order.token,
      settings_token: Game::Market::CurrentSettings.call.token).value!
  end

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
    assert_selector recent_rows, count: 1
    assert_selector recent_rows, text: /Tin Soldier.*CANCELLED.*PiCoins returned/m
    assert_no_selector "section[aria-labelledby=my-orders-in-progress-heading]"
    assert_no_selector ".empty-state__line"
    assert_selector available("1,000")
    committed("0 committed")
  end

  test "served, expired and cancelled orders show under RECENTLY ENDED with what became of them" do
    served = order!(@player, catalog_card_seasons(:rare_card_one), 300)
    serve!(served, catalog_card_seasons(:rare_card_one))
    order!(@player, catalog_card_seasons(:common_card_one), 200, expires_at: 1.minute.ago)
    Game::Market::ExpireDueOrdersJob.perform_now
    cancelled = order!(@player, catalog_card_seasons(:uncommon_card_one), 100)
    Game::Market::CancelOrder.new.call(player: @player, order_id: cancelled.id).value!
    sign_in_through_the_site(@player)

    visit market_my_orders_path(locale: :en)

    assert_selector "#my-orders-recent-heading", text: "RECENTLY ENDED"
    assert_selector recent_rows, count: 3
    assert_selector recent_rows, text: /Blue Depths.*SERVED.*Sold by Ada · Rare S1/m
    assert_selector recent_rows, text: /Tin Soldier.*EXPIRED.*PiCoins returned/m
    assert_selector recent_rows, text: /Green Hills.*CANCELLED.*PiCoins returned/m
    assert_no_selector "#{recent_rows} button"
    assert_selector available(700)
  end

  test "an order served after the page drew is refused on cancel with the served line, the row then SERVED" do
    order = order!(@player, catalog_card_seasons(:common_card_one), 300)
    sign_in_through_the_site(@player)
    visit market_my_orders_path(locale: :en)
    assert_selector "section[aria-labelledby=my-orders-in-progress-heading] .market-row", text: "Tin Soldier"

    serve!(order, catalog_card_seasons(:common_card_one))
    find("button[aria-label='Cancel the order, Tin Soldier']").click
    within("dialog#cancel-order-#{order.token}") { click_button "CANCEL THE ORDER" }

    assert_text "This order has just been served."
    assert_selector recent_rows, text: /Tin Soldier.*SERVED.*Sold by Ada · Common S1/m
    assert_no_selector "section[aria-labelledby=my-orders-in-progress-heading]"
    assert_selector available(700)
  end

  test "on a phone the chip row scrolls MY ORDERS into view, merged into the panel" do
    sign_in_through_the_site(@player)
    resize_to 360, 780
    visit market_my_orders_path(locale: :fr)

    assert_selector ".market-screen__chips .tabs__tab--current", text: "MES ORDRES"
    eventually("the current chip shows whole, clear of the fade, and covers the panel's edge") do
      evaluate_script(<<~JS)
        (() => {
          const row = document.querySelector(".market-screen__chips")
          const chip = row.querySelector(".tabs__tab--current").getBoundingClientRect()
          const edges = row.getBoundingClientRect()
          const panel = row.nextElementSibling.getBoundingClientRect()
          return chip.left >= edges.left && Math.round(chip.right) <= edges.right - 32 && chip.bottom > panel.top && chip.bottom <= edges.bottom && row.scrollHeight === row.clientHeight
        })()
      JS
    end
  end

  test "a visitor sees MY ORDERS greyed and is led to the landing from the form" do
    visit market_path(locale: :en)
    assert_selector ".market-screen__chips .tabs__tab--disabled", text: "MY ORDERS"

    visit new_market_card_order_path(locale: :en, slug: "tin-soldier")
    assert_current_path home_path(locale: :en)
  end
end
