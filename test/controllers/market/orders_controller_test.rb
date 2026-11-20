require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/counting_rate_limit"

class Market::OrdersControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @settings = open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000)
  end

  def place(price: "100", locale: :en, settings_token: @settings.token)
    post market_card_orders_path(locale:, slug: "tin-soldier"), params: { price:, settings_token: }
  end

  test "a visitor is sent to the landing from the form and from the post" do
    get new_market_card_order_path(locale: :en, slug: "tin-soldier")
    assert_redirected_to home_path(locale: :en)

    assert_no_difference(-> { Game::Market::Order.count }) { place }
    assert_redirected_to home_path(locale: :en)
  end

  test "the form draws the field empty, the lowest minimum, every rarity chip and the order's duration" do
    sign_in(@player)

    get new_market_card_order_path(locale: :en, slug: "tin-soldier")

    assert_response :success
    assert_select "h1", "Tin Soldier"
    assert_select "#order-price[value='']"
    assert_select "#order-lowest", "At least 13"
    assert_select ".order-reach__chip", 5
    assert_select ".order-reach__chip [data-reach=off]", text: "Epic from 223"
    assert_select "input[name=settings_token][value=?]", @settings.token
    assert_select ".order-form__fact dd", text: "7 days"
    assert_no_match(/\b#{@player.id}\b.*order/, response.body.scan(/data-[\w-]+="[^"]*"/).join(" "))
  end

  test "an unknown card is a 404" do
    sign_in(@player)

    get new_market_card_order_path(locale: :en, slug: "no-such-game")

    assert_response :not_found
  end

  test "a placed order leads to MES ORDRES with the order named in the flash" do
    sign_in(@player)

    assert_difference(-> { Game::Market::Order.count }) { place }

    order = Game::Market::Order.last
    assert_redirected_to market_my_orders_path(locale: :en)
    assert_equal order.token, flash[:placed_order]
    assert_not_includes response.location, order.id.to_s
  end

  test "a refusal keeps the typed value, marks the field invalid and redraws the settings" do
    sign_in(@player)

    place(price: "1,001")

    assert_response :unprocessable_content
    assert_select "#order-price[value=?][aria-invalid=true]", "1,001"
    assert_select "#order-error", "You can commit at most 1,000."
    assert_select ".order-reach__chip--reached", 5 - 1
    assert_select ".order-form__sentence", "Your price reaches commons, uncommons, rares, and epics. Legendaries from 70,000."
  end

  test "a price under every minimum names the lowest rarity, in both languages" do
    sign_in(@player)

    place(price: "5")
    assert_select "#order-error", "At least 13 for a Common."

    place(price: "5", locale: :fr)
    assert_select "#order-error", "Au moins 13 pour une Commune."
  end

  test "a second order on the card names the running one" do
    sign_in(@player)
    place(price: "100")

    place(price: "200")

    assert_select "#order-error", "You already have an order on Tin Soldier: 100, 7 d left."
  end

  test "a stale version redraws the form with the version in force" do
    sign_in(@player)
    newer = open_market!(first_opened_at: 1.day.ago)

    place(settings_token: @settings.token)

    assert_response :unprocessable_content
    assert_select "input[name=settings_token][value=?]", newer.token
  end

  test "a suspended market draws the banner and a disabled button" do
    close_market!(first_opened_at: 1.day.ago)
    sign_in(@player)

    get new_market_card_order_path(locale: :en, slug: "tin-soldier")

    assert_select "#market-suspended-banner"
    assert_select "button.order-form__submit[disabled]"
  end

  test "the eleventh post of a minute is throttled" do
    sign_in(@player)

    with_counting_rate_limit(Market::OrdersController) { 11.times { place(price: "abc") } }

    assert_redirected_to new_market_card_order_path(locale: :en, slug: "tin-soldier")
  end
end
