require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/counting_rate_limit"
require_relative "../../support/market_listings"
require_relative "../../support/market_orders"
require_relative "../../support/custom_sets"

class Market::OrdersControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include CustomSets
  include MarketListings
  include MarketOrders
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
    assert_select "#order-error[tabindex='-1'][autofocus]", "You can commit at most 1,000."
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

  def open_form(from: nil, locale: :en) = get new_market_card_order_path(locale:, slug: "tin-soldier", from:)

  test "a running order shows its line and MY ORDERS in place of the form" do
    sign_in(@player)
    place(price: "100")

    open_form

    assert_response :success
    assert_select "#order-running:not([autofocus])", "You already have an order on Tin Soldier: 100, 7 d left."
    assert_select "#order-form-yours ~ a.button--link[href=?]", market_my_orders_path(locale: :en), "MY ORDERS"
    assert_select "#order-form", 0
    assert_select "#order-price", 0
  end

  test "a second order on the card is refused with the running line, focused" do
    sign_in(@player)
    place(price: "100")

    assert_no_difference(-> { Game::Market::LedgerEntry.count }) { place(price: "200") }

    assert_response :unprocessable_content
    assert_select "#order-running[tabindex='-1'][autofocus]", "You already have an order on Tin Soldier: 100, 7 d left."
    assert_select "#order-form", 0
  end

  test "the open listings of the game are drawn, the soonest to end first, each linked to its listing by token" do
    seller = accounts_players(:moderator).tap { it.update!(persona_name: "Ada") }
    later = listing!(seller:, card_season: catalog_card_seasons(:common_card_one), current_price: 40, hours: 24)
    sooner = listing!(seller: accounts_players(:administrator).tap { it.update!(persona_name: "Bob") },
      card_season: catalog_card_seasons(:common_card_one), current_price: 1_200, hours: 2)
    sign_in(@player)

    open_form

    assert_select "#order-form-available", "AVAILABLE NOW"
    assert_select ".order-listing", 2
    assert_select ".order-listing:first-child .order-listing__edition", "Common · S1"
    assert_select ".order-listing:first-child .order-listing__seller", "Sold by Bob"
    assert_select ".order-listing:first-child .order-listing__price", "1,200"
    assert_select ".order-listing:first-child a.button--link[href=?][aria-label=?]", market_listing_path(locale: :en, token: sooner.token),
      "See the listing, Common season 1, sold by Bob, 1,200 PiCoins", "SEE THE LISTING"
    assert_select ".order-listing:last-child a[href=?]", market_listing_path(locale: :en, token: later.token)
    assert_select ".order-listing", text: /0 offers/
    assert_select "#order-price"
  end

  test "with no listing one line says nobody is selling the card, in both languages" do
    sign_in(@player)

    open_form
    assert_select ".order-listing", 0
    assert_select ".empty-state__line", "Nobody is selling Tin Soldier right now. A player who has one will see your price when selling or entrusting it."

    open_form(locale: :fr)
    assert_select ".empty-state__line", "Personne ne vend Soldat de plomb pour le moment. Un joueur qui en a un verra votre prix en le vendant ou en le confiant."
  end

  test "a goal missing the card heads the form with its bookmark" do
    Game::AddGoal.new.call(player: @player, custom_set: create_custom_set(@player, name: "Wishlist").token).value!
    sign_in(@player)

    open_form

    assert_select ".order-form__goal .goal-bookmark[aria-hidden=true]", "1"
    assert_select ".order-form__goal span:not(.goal-bookmark):not(.goal-bookmark__shape)", "You are missing this card for Wishlist"
  end

  test "no goal head when the card is in no goal" do
    sign_in(@player)

    open_form

    assert_select ".order-form__goal", 0
  end

  test "the best current order is another player's price standing over an hour, never a tied account's, and shows no name" do
    other = buyer!.tap { fund!(it, 1_000) }
    tied = buyer!.tap { fund!(it, 1_000) }.tap { it.update!(persona_name: "Twin") }
    low, high = [ @player, tied ].sort_by(&:id)
    Game::Market::TiedAccount.create!(low_account: low, high_account: high, signal: "one_way_trades", facts: {}, refreshed_at: Time.current)
    order!(other, catalog_card_seasons(:common_card_one), 80, created_at: 2.hours.ago)
    order!(tied, catalog_card_seasons(:common_card_one), 120, created_at: 2.hours.ago)
    sign_in(@player)

    open_form

    assert_select ".order-form__best", "80"
    assert_not_includes response.body, "Twin"
    assert_not_includes response.body, tied.token
    assert_not_includes response.body, other.token
  end

  test "with no visible order the best current order is a dash, read as none" do
    order!(buyer!.tap { fund!(it, 1_000) }, catalog_card_seasons(:common_card_one), 80, created_at: 30.minutes.ago)
    sign_in(@player)

    open_form

    assert_select ".order-form__best span[aria-hidden=true]", "—"
    assert_select ".order-form__best .visually-hidden", "none"
  end

  test "the phone back names the screen the form was opened from and the form keeps it" do
    sign_in(@player)

    open_form(from: "my_orders")
    assert_select "a.top-bar__phone-back[href=?]", market_my_orders_path(locale: :en), "My orders"
    assert_select "input[type=hidden][name=from][value=my_orders]"

    open_form(from: "card")
    assert_select "a.top-bar__phone-back[href=?][data-controller=history-back]", card_path(locale: :en, slug: "tin-soldier"), "Card"

    open_form
    assert_select "a.top-bar__phone-back[href=?]", market_path(locale: :en), "Market"
    assert_select "input[name=from]", 0

    open_form(from: "elsewhere")
    assert_select "a.top-bar__phone-back[href=?]", market_path(locale: :en), "Market"

    post market_card_orders_path(locale: :en, slug: "tin-soldier"), params: { price: "5", settings_token: @settings.token, from: "my_orders" }
    assert_select "a.top-bar__phone-back[href=?]", market_my_orders_path(locale: :en), "My orders"
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

  test "a market suspended at the press draws the closed line under the disabled button, focused" do
    sign_in(@player)
    close_market!(first_opened_at: 1.day.ago)

    assert_no_difference(-> { Game::Market::Order.count }) { place }

    assert_response :unprocessable_content
    assert_select "#market-suspended-banner"
    assert_select "button.order-form__submit[disabled] + #order-closed[role=alert][tabindex='-1'][autofocus]", "The market is closed for now."
    assert_select "#order-error[hidden]"
    assert_select "#order-price:not([aria-invalid])"
  end

  test "the eleventh post of a minute is throttled" do
    sign_in(@player)

    with_counting_rate_limit(Market::OrdersController) { 11.times { place(price: "abc") } }

    assert_redirected_to new_market_card_order_path(locale: :en, slug: "tin-soldier")
  end

  test "with no listing, the form lists the Archives' editions of the game, each opening the purchase confirmation" do
    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    Game::Market::ArchiveStock.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    sign_in(@player)

    get new_market_card_order_path(locale: :fr, slug: "blue-depths")

    assert_select ".order-form__lead", "Aucune annonce de joueur pour Profondeurs bleues."
    assert_select ".order-archive .order-listing__edition", /Rare · S1\s+ARCHIVES/
    assert_select ".order-archive .order-listing__facts", /prix fixe\s+500/
    assert_select ".order-archive a.button[href=?][data-turbo-frame=archive-purchase][data-action='purchase-dialog#open'][aria-label=?]",
      new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1),
      "Acheter aux Archives, Profondeurs bleues Rare saison 1, 500 PiCoins", text: "ACHETER · 500"
    assert_select ".order-form[data-controller=purchase-dialog] dialog#archive-purchase-dialog"
  end

  test "a game with an open listing shows the listing and no Archives line" do
    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    Game::Market::ArchiveStock.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    listing!(seller: accounts_players(:moderator), card_season: catalog_card_seasons(:rare_card_one))
    sign_in(@player)

    get new_market_card_order_path(locale: :fr, slug: "blue-depths")

    assert_select ".order-listing", 1
    assert_select ".order-archive", 0
    assert_select "dialog#archive-purchase-dialog", 0
  end

  test "a suspended market keeps the Archives lines with ACHETER disabled" do
    close_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    Game::Market::ArchiveStock.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    sign_in(@player)

    get new_market_card_order_path(locale: :fr, slug: "blue-depths")

    assert_select ".order-archive button.button[disabled]", "ACHETER · 500"
    assert_select "dialog#archive-purchase-dialog", 0
  end
end
