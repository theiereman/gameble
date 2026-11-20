require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/market_bidding"
require_relative "../../support/counting_rate_limit"

class Market::OrderCancellationsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include MarketAuctions
  include MarketBidding
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @settings = open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000)
    @order = Game::Market::PlaceOrder.new.call(player: @player, card_id: catalog_cards(:common_card).id, price: 300, settings_token: @settings.token).value!
  end

  def cancel(token: @order.token, locale: :en) = post(market_order_cancellation_path(locale:, token:))

  test "a visitor is sent to the landing and nothing changes" do
    cancel

    assert_redirected_to home_path(locale: :en)
    assert_equal "open", @order.reload.status
  end

  test "the player cancels and lands on MES ORDRES with the PiCoins back, in both languages" do
    sign_in(@player)

    cancel

    assert_redirected_to market_my_orders_path(locale: :en)
    assert_equal "Order cancelled: your 300 PiCoins are returned to you.", flash[:notice]
    assert_equal [ 1_000, 0 ], figures(@player)
    assert_not_includes response.location, @order.id.to_s

    french = Game::Market::PlaceOrder.new.call(player: @player, card_id: catalog_cards(:rare_card).id, price: 300, settings_token: @settings.token).value!
    cancel(token: french.token, locale: :fr)
    assert_equal "Ordre annulé : vos 300 PiCoins vous sont rendus.", flash[:notice]
  end

  test "an order no longer open is refused with its line" do
    @order.update_columns(status: "cancelled")
    sign_in(@player)

    cancel

    assert_redirected_to market_my_orders_path(locale: :en)
    assert_equal "This order is no longer in progress.", flash[:alert]
  end

  test "another player's order is refused as not found, and an unknown token is a 404" do
    sign_in(accounts_players(:moderator))

    cancel
    assert_equal "This order does not exist.", flash[:alert]
    assert_equal "open", @order.reload.status

    cancel(token: "A" * 24)
    assert_response :not_found
  end

  test "the twenty-first cancel of a minute is throttled" do
    sign_in(@player)

    with_counting_rate_limit(Market::OrderCancellationsController) { 21.times { cancel(token: "A" * 24) } }

    assert_redirected_to market_my_orders_path(locale: :en)
  end
end
