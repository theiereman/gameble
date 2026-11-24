require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/counting_rate_limit"
require_relative "../../support/market_listings"
require_relative "../../support/market_orders"
require_relative "../../support/custom_sets"
require_relative "../../support/game_sets"
require_relative "../../support/singleton_stub"

class Market::OrdersControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include CustomSets
  include GameSets
  include MarketListings
  include MarketOrders
  include MarketAuctions
  include MarketSettings
  include SingletonStub
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
    assert_select ".order-form__conversion", "If a player lists this card at auction at this price or lower, your order becomes a bid and your PiCoins stay held in it."
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

  test "an order refused as already open while none is open any more redraws the form with the retry line" do
    sign_in(@player)

    stub_singleton(Game::Market::Order, :create!, proc { raise ActiveRecord::RecordNotUnique }) do
      assert_no_difference(-> { Game::Market::LedgerEntry.count }) { place(price: "200") }
    end

    assert_response :unprocessable_content
    assert_select "#order-running", 0
    assert_select "#order-error", "The Archives are busy right now. Try again in a moment."
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

  test "a throttled post returns to the form keeping where it was opened from and its goal chain" do
    sign_in(@player)

    with_counting_rate_limit(Market::OrdersController) do
      11.times { post market_card_orders_path(locale: :en, slug: "tin-soldier"), params: { price: "abc", from: "card", goal: "1", of: "3" } }
    end

    assert_redirected_to new_market_card_order_path(locale: :en, slug: "tin-soldier", from: "card", goal: "1", of: "3")
  end

  test "with no listing, the form lists the Archives' editions of the game, each opening the purchase confirmation" do
    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    Game::Market::ArchiveStock.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    sign_in(@player)

    get new_market_card_order_path(locale: :fr, slug: "blue-depths")

    assert_select ".order-form__lead", "Aucune annonce de joueur pour Profondeurs bleues."
    assert_select ".order-archive[data-archive-offer='blue-depths-1'] .order-listing__edition", /Rare · S1\s+ARCHIVES/
    assert_select ".order-archive .order-listing__facts", /prix fixe\s+500/
    assert_select ".order-archive a.button[href=?][data-turbo-frame=archive-purchase][data-action='purchase-dialog#open'][aria-label=?]",
      new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1),
      "Acheter aux Archives, Profondeurs bleues Rare saison 1, 500 PiCoins", text: "ACHETER · 500"
    assert_select ".order-form[data-controller=purchase-dialog] dialog#archive-purchase-dialog"
  end

  test "an Archive offer of a capped rarity carries what is left of the cap, then the next purchase date" do
    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    Game::Market::ArchiveStock.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    sign_in(@player)

    get new_market_card_order_path(locale: :fr, slug: "blue-depths")
    assert_select ".order-archive .archive-offer__cap[data-archive-cap=rare]", "Encore 1 Rare par jour"

    Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:rare_card_one).id, purchase_token: SecureRandom.base58(24),
      price: 500, settings_id: Game::Market::CurrentSettings.call.id, created_at: 2.hours.ago)
    get new_market_card_order_path(locale: :en, slug: "blue-depths")
    assert_select ".order-archive .archive-offer__cap", /\A1 Rare per day · next on /
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

  def chain_goal
    insert_set(%i[common_card_one uncommon_card_one].map { catalog_card_seasons(it).id }, { complete: 2 })
    Game::AddGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
  end

  def place_in_chain(slug: "tin-soldier", price: "100", goal: 1, of: 2)
    post market_card_orders_path(locale: :en, slug:), params: { price:, settings_token: @settings.token, goal:, of: }
  end

  test "an order placed from a goal's chain opens the form on its next card, the result above the heading that takes the focus" do
    chain_goal
    sign_in(@player)

    place_in_chain

    assert_redirected_to new_market_card_order_path(locale: :en, slug: "green-hills", goal: 1, of: 2)
    follow_redirect!
    assert_select "p#order-chain-result + h1#order-form-heading[tabindex='-1'][autofocus][aria-describedby=order-chain-result]", "Green Hills"
    assert_select "#order-chain-result", "Order placed on Tin Soldier: 100 PiCoins held. Card 1 of 2."
    assert_select "#order-form input[type=hidden][name=goal][value='1']"
    assert_select "#order-form input[type=hidden][name=of][value='2']"
  end

  test "the chain's last order returns to the goal's album, its result a toast and the album heading focused" do
    chain_goal
    sign_in(@player)
    place

    place_in_chain(slug: "green-hills")

    assert_redirected_to library_set_path(locale: :en, kind: "theme", key: "roguelike")
    assert_equal "Order placed on Green Hills: 100 PiCoins held. Card 2 of 2.", flash[:notice]
    follow_redirect!
    assert_select "#toasts", text: /Card 2 of 2\./
    assert_select "#set-album-heading[autofocus]"
    assert_select "#set-album-goal a", false
  end

  test "a chain's length missing or under what is left counts from the cards left" do
    chain_goal
    sign_in(@player)

    place_in_chain(of: "x")

    assert_equal "Order placed on Tin Soldier: 100 PiCoins held. Card 1 of 2.", flash[:order_chain]
  end

  test "a refused order in a chain redraws the form keeping the chain" do
    chain_goal
    sign_in(@player)

    place_in_chain(price: "5")

    assert_response :unprocessable_content
    assert_select "#order-form input[name=goal][value='1'] + input[name=of][value='2']"
    assert_select "#order-chain-result", 0
    assert_select "h1#order-form-heading:not([autofocus])"
  end

  test "a goal number that is none of the player's leads to MY ORDERS, as an order without a chain" do
    chain_goal
    sign_in(@player)

    place_in_chain(goal: 7)

    assert_redirected_to market_my_orders_path(locale: :en)
    assert_equal Game::Market::Order.last.token, flash[:placed_order]
  end
end
