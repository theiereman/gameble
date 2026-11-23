require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/market_listings"
require_relative "../../support/market_orders"

class Market::MyOrdersControllerTest < ActionDispatch::IntegrationTest
  include MarketAuctions
  include MarketListings
  include MarketOrders
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
    assert_select "a.market-row__title[href=?]", new_market_card_order_path(locale: :en, slug: "tin-soldier", from: "my_orders"), "Tin Soldier"
    assert_select ".market-row__editions", "every edition"
    assert_select ".market-row .order-pill", 3
    assert_select ".market-row .order-pill .visually-hidden", "Rare"
    assert_select ".market-row__chip", "IN PROGRESS"
    assert_select "button[aria-label=?]", "Cancel the order, Tin Soldier"
    assert_select "form[action=?]", market_order_cancellation_path(locale: :en, token: order.token)
    assert_select ".order-result", 0
    assert_no_match(/order[\w-]*[-_\/]#{order.id}\b/, response.body)
  end

  test "an open order with a listing above its price shows who sells it, for how much, and a link to the Annonce, in both languages" do
    order = place(100)
    seller = accounts_players(:moderator)
    seller.update_columns(persona_name: "Max")
    listing = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), starting_price: 150)
    Game::Market::Notice.record(player_id: @player.id, listing_id: listing.id, order_id: order.id, kind: "listed_above_order", other_player_id: seller.id,
      amount: 150)
    sign_in(@player)

    get market_my_orders_path(locale: :en)
    assert_select ".market-row__note", text: /Max is selling Tin Soldier for 150.*, above your order\./m
    assert_select ".market-row__note a.button--link[href=?]", market_listing_path(locale: :en, token: listing.token), "SEE THE LISTING ▸"

    get market_my_orders_path(locale: :fr)
    assert_select ".market-row__note", text: /Max vend Soldat de plomb à 150.*, au-dessus de votre ordre\./m
    assert_select ".market-row__note a.button--link", "VOIR L'ANNONCE ▸"
  end

  def ended!(card_season, status, ended_at)
    order = order!(@player, card_season, 100)
    served = { seller_id: @seller.id, served_card_season_id: card_season.id, served_at: ended_at, average_after_sale: 100 } if status == "served"
    order.update_columns(status:, updated_at: ended_at, **served.to_h)
    order
  end

  test "orders ended this week are rows under RECENTLY ENDED, the latest first, with their chip and line and no cancel" do
    @seller = Accounts::Player.create!(persona_name: "Ada")
    open = order!(@player, catalog_card_seasons(:legendary_card_one), 100)
    ended!(catalog_card_seasons(:rare_card_one), "served", 1.hour.ago)
    ended!(catalog_card_seasons(:common_card_one), "expired", 2.days.ago)
    ended!(catalog_card_seasons(:uncommon_card_one), "cancelled", 3.hours.ago)
    ended!(catalog_card_seasons(:portal_one), "expired", 8.days.ago)
    ended!(catalog_card_seasons(:portal_one), "withdrawn", 1.hour.ago)
    sign_in(@player)

    get market_my_orders_path(locale: :en)

    assert_select "#my-orders-in-progress-heading", "IN PROGRESS"
    assert_select "section[aria-labelledby=my-orders-in-progress-heading] .market-row", 1
    assert_select "form[action=?]", market_order_cancellation_path(locale: :en, token: open.token)
    assert_select "#my-orders-recent-heading", "RECENTLY ENDED"
    recent = "section[aria-labelledby=my-orders-recent-heading]"
    assert_equal [ "Blue Depths", "Green Hills", "Tin Soldier" ], css_select("#{recent} .market-row__title").map { it.text.strip }
    assert_equal %w[SERVED CANCELLED EXPIRED], css_select("#{recent} .market-row__chip").map { it.text.strip }
    assert_select recent do
      assert_select ".market-row__chip--lime", 1
      assert_select ".market-row__chip--muted", 2
      assert_select ".market-row__note", 3
      assert_select ".market-row__note", "Sold by Ada · Rare S1"
      assert_select ".market-row__note", text: "PiCoins returned", count: 2
      assert_select "button", false
      assert_select "form", false
    end

    get market_my_orders_path(locale: :fr)

    assert_select "#my-orders-recent-heading", "TERMINÉS RÉCEMMENT"
    assert_equal %w[SERVI ANNULÉ EXPIRÉ], css_select("#{recent} .market-row__chip").map { it.text.strip }
    assert_select ".market-row__note", "Vendue par Ada · Rare S1"
    assert_select ".market-row__note", text: "PiCoins rendus", count: 2
  end

  test "a player whose orders all ended this week sees only RECENTLY ENDED" do
    ended!(catalog_card_seasons(:common_card_one), "cancelled", 1.hour.ago)
    sign_in(@player)

    get market_my_orders_path(locale: :en)

    assert_select "#my-orders-in-progress-heading", false
    assert_select "#my-orders-recent-heading[data-row-focus-target=heading]", "RECENTLY ENDED"
    assert_select ".empty-state__line", text: "You have placed no order.", count: 0
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
