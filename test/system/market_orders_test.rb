require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/market_listings"
require_relative "../support/holdings"

class MarketOrdersSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketAuctions
  include MarketListings
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
    assert_no_selector ".empty-state__line", text: "You have placed no order."
    assert_selector available("1,000")
    committed("0 committed")
  end

  test "the form lists what is for sale now, and reopened from MY ORDERS shows the running order instead of the field" do
    seller = accounts_players(:moderator).tap { it.update!(persona_name: "Ada") }
    first = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), current_price: 40, hours: 2)
    second = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), current_price: 60, hours: 24)
    sign_in_through_the_site(@player)

    visit new_market_card_order_path(locale: :en, slug: "tin-soldier")

    assert_selector "#order-form-available", text: "AVAILABLE NOW"
    assert_selector ".order-listing", count: 2
    assert_selector "a.button--link[href='#{market_listing_path(locale: :en, token: first.token)}']", text: "SEE THE LISTING"
    assert_selector "a.button--link[href='#{market_listing_path(locale: :en, token: second.token)}']", text: "SEE THE LISTING"
    fill_in "order-price", with: "300"
    find(".order-form__submit").click

    assert_selector "#order-result-heading:focus", text: "ORDER PLACED ON Tin Soldier"
    find("section[aria-labelledby=my-orders-in-progress-heading] a.market-row__title", text: "Tin Soldier").click

    assert_selector "#order-running", text: "You already have an order on Tin Soldier: 300, 7 d left."
    assert_selector "a.button--link[href='#{market_my_orders_path(locale: :en)}']", text: "MY ORDERS"
    assert_no_selector "#order-price"
    assert_no_selector ".order-form__submit"
    assert_selector ".top-bar__phone-back", text: "My orders", visible: :all
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

  def open_bell
    find(".bell__button").click
    assert_selector "#bell-panel:popover-open"
  end

  test "a listing above an order shows under MY ORDERS and in the bell, and the bell tells of the order served" do
    order = order!(@player, catalog_card_seasons(:common_card_one), 100)
    Game::Market::RebuildWanted.new.call(player: @player).value!
    lister = accounts_players(:administrator).tap { it.update!(persona_name: "Eve") }
    fund!(lister, 1_000)
    hold(lister, catalog_card_seasons(:common_card_one).id, 1)
    listing = Game::Market::ListCard.new.call(player: lister, card_season_id: catalog_card_seasons(:common_card_one).id, starting_price: 150,
      duration_hours: 24, settings_token: Game::Market::CurrentSettings.call.token).value!
    sign_in_through_the_site(@player)

    visit market_my_orders_path(locale: :en)

    assert_selector ".market-row__note", text: /Eve is selling Tin Soldier for\s+150\s*, above your order\./
    assert_selector ".market-row__note a.button--link[href='#{market_listing_path(locale: :en, token: listing.token)}']", text: "SEE THE LISTING ▸"
    open_bell
    within("#bell-panel") { assert_selector ".bell__line", text: /Tin Soldier is on sale for 150.*, above your order\./ }

    serve!(order, catalog_card_seasons(:common_card_one))
    visit market_my_orders_path(locale: :en)
    open_bell

    within("#bell-panel") do
      assert_selector ".bell__line", text: /Your order on Tin Soldier was filled: the card joins your collection\./
      assert_no_selector ".bell__line", text: /above your order/
    end
  end

  test "the wanted cards on sale are one bell line, read once marked read on reload" do
    lister = accounts_players(:administrator)
    [ :common_card_one, :rare_card_one ].each do |name|
      order!(@player, catalog_card_seasons(name), 300)
      listing = listing!(seller: lister, card_season: catalog_card_seasons(name), starting_price: 200)
      Game::Market::Notice.record(player_id: @player.id, listing_id: listing.id, kind: "wanted", amount: 200)
    end
    Game::Market::RebuildWanted.new.call(player: @player).value!
    sign_in_through_the_site(@player)

    open_bell
    within("#bell-panel") do
      assert_selector ".bell__line[data-bell-read=false]", text: "2 cards you are looking for are on sale."
      click_button "Mark all as read"
    end
    eventually("the read reaches the server") { Game::BellRead.exists?(player_id: @player.id, key: "wanted:grouped") }

    visit home_path(locale: :en)
    open_bell

    assert_selector "#bell-panel .bell__line[data-bell-key^='wanted:grouped:'][data-bell-read=true]", visible: :all
  end

  test "a visitor sees MY ORDERS greyed and is led to the landing from the form" do
    visit market_path(locale: :en)
    assert_selector ".market-screen__chips .tabs__tab--disabled", text: "MY ORDERS"

    visit new_market_card_order_path(locale: :en, slug: "tin-soldier")
    assert_current_path home_path(locale: :en)
  end
end
