require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"

class Market::MyOrdersControllerTest < ActionDispatch::IntegrationTest
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @settings = open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000)
  end

  def place(price = 100, card: catalog_cards(:common_card))
    Game::Market::PlaceOrder.new.call(player: @player, card_id: card.id, price:, settings_token: @settings.token).value!
  end

  test "a visitor is sent to the landing" do
    get market_my_orders_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
  end

  test "a player with no order sees the one quiet line, in both languages" do
    sign_in(@player)

    get market_my_orders_path(locale: :en)
    assert_select ".empty-state__line", "You have placed no order."
    assert_select ".tabs__tab--current", "MY ORDERS"

    get market_my_orders_path(locale: :fr)
    assert_select ".empty-state__line", "Vous n'avez passé aucun ordre."
  end

  test "open orders are rows with their rarity pills, price held and a cancel named after the card, and no database id" do
    order = place(100)
    sign_in(@player)

    get market_my_orders_path(locale: :en)

    assert_select "#my-orders-in-progress-heading", "IN PROGRESS"
    assert_select ".market-row", 1
    assert_select "a.market-row__title[href=?]", new_market_card_order_path(locale: :en, slug: "tin-soldier"), "Tin Soldier"
    assert_select ".market-row__editions", "every edition"
    assert_select ".market-row .order-pill", 3
    assert_select ".market-row .order-pill .visually-hidden", "Rare"
    assert_select ".market-row__chip", "IN PROGRESS"
    assert_select "button[aria-label=?]", "Cancel the order, Tin Soldier"
    assert_select "form[action=?]", market_order_cancellation_path(locale: :en, token: order.token)
    assert_select ".order-result", 0
    assert_no_match(/order[\w-]*[-_\/]#{order.id}\b/, response.body)
  end

  test "the order just placed opens the result panel, its heading focused" do
    sign_in(@player)
    post market_card_orders_path(locale: :en, slug: "tin-soldier"), params: { price: "100", settings_token: @settings.token }

    follow_redirect!

    assert_select ".order-result h2#order-result-heading[data-row-focus-target=heading]", "ORDER PLACED ON Tin Soldier"
    assert_select "[data-row-focus-landing-value='']"
    assert_select ".order-result__fact dd", text: /900 available/
    assert_select ".order-result__words", text: "commons, uncommons, and rares"
    assert_select ".order-result__words", text: "7 days"
  end

  test "the result panel joins the rarities the French way" do
    sign_in(@player)
    post market_card_orders_path(locale: :fr, slug: "tin-soldier"), params: { price: "100", settings_token: @settings.token }

    follow_redirect!

    assert_select ".order-result__words", text: "communes, peu communes et rares"
  end
end
