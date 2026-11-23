require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/steam_sign_in"

# A goal's missing cards the player has no open order on: a line under its
# OBJECTIFS row naming the first two, and on its own album a link opening the
# order form on the first, which chains to the next.
class LibraryGoalOrdersTest < ActionDispatch::IntegrationTest
  include CustomSets
  include GameSets
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings
  include SteamSignIn

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html" }.freeze

  def sign_in_origin = "/fr"

  def control = Nokogiri::HTML5.fragment(css_select("turbo-stream[target=set-album-goal] template").sole.inner_html)

  setup do
    @player = accounts_players(:player)
    @seasons = %i[rare_card_one common_card_one uncommon_card_one portal_one].map { catalog_card_seasons(it) }
    open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 10_000)
  end

  def roguelike(members = @seasons) = insert_set(members.map(&:id), { complete: members.size })

  def add(**aim) = Game::AddGoal.new.call(player: @player, **aim).value!

  def line(row = 0) = css_select("#goals .goals__list > li")[row].css(".goal-row + p.goal-orders").sole

  def album = get library_set_path(locale: :fr, kind: "theme", key: "roguelike")

  def orders_link = "#set-album-goal .goal-control__buttons a.button.button--secondary.button--small:not(.goal-button)"

  test "after a goal's row, its line names the first two cards to order, each a link to its order form, then how many more" do
    roguelike
    add(kind: "studio", key: "valve")
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    get library_path(locale: :fr)

    roguelike_line = line(1)
    assert_equal "4 cartes à commander : Profondeurs bleues · Soldat de plomb · + 2", roguelike_line.text
    assert_equal [ [ new_market_card_order_path(locale: :fr, slug: "blue-depths"), "Passer un ordre sur Profondeurs bleues, objectif 2 : Roguelike" ],
      [ new_market_card_order_path(locale: :fr, slug: "tin-soldier"), "Passer un ordre sur Soldat de plomb, objectif 2 : Roguelike" ] ],
      roguelike_line.css("a").map { [ it["href"], it["aria-label"] ] }
    assert_select "[style]", false
  end

  test "one card left names it alone; a card already ordered is skipped" do
    roguelike(@seasons.first(2))
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    order!(@player, @seasons.first, 100)
    get library_path(locale: :en)
    assert_equal "1 card to order: Tin Soldier", line.text

    order!(@player, @seasons.second, 100)
    get library_path(locale: :en)
    assert_select ".goal-orders", false
  end

  test "no line nor orders link while the market is suspended" do
    roguelike
    add(kind: "theme", key: "roguelike")
    close_market!(first_opened_at: 1.day.ago)
    sign_in(@player)

    get library_path(locale: :fr)
    assert_select "#goals .goal-row"
    assert_select ".goal-orders", false

    album
    assert_select "#set-album-goal button.goal-button"
    assert_select orders_link, false
  end

  test "a goal's album holds beside its goal button the link to order its first missing card, chaining over all of them" do
    roguelike
    add(kind: "theme", key: "roguelike")
    order!(@player, @seasons.first, 100)
    sign_in(@player)

    album

    assert_select ".set-album__actions #set-album-goal .goal-control__buttons > form.button-form button.goal-button", /Objectif 1 · Retirer/
    assert_select "#set-album-goal .goal-control__buttons > .button-form + a[href=?][aria-label=?]",
      new_market_card_order_path(locale: :fr, slug: "tin-soldier", goal: 1, of: 3), "Passer des ordres, 3 cartes manquantes", text: "Passer des ordres · 3"
    assert_select "#set-album-heading:not([autofocus])"
  end

  test "a set that is no goal, or a goal fully ordered, offers no orders link" do
    roguelike(@seasons.first(1))
    sign_in(@player)

    album
    assert_select "#set-album-goal form button.goal-button", "Marquer comme objectif"
    assert_select orders_link, false

    add(kind: "theme", key: "roguelike")
    order!(@player, @seasons.first, 100)
    album
    assert_select "#set-album-goal button.goal-button"
    assert_select orders_link, false
  end

  test "a custom set's goal album holds the orders link too" do
    custom_set = create_custom_set(@player)
    add(custom_set: custom_set.token)
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)

    assert_select "#set-album-goal a[href^=?]", "/en/market/order/cards/", text: "Place orders · 3"
  end

  test "marking the album as a goal by stream redraws the control with the orders link; removing it drops the link" do
    roguelike
    sign_in(@player)

    post library_goals_path(locale: :fr), params: { kind: "theme", key: "roguelike" }, headers: STREAM
    assert_equal "Passer des ordres · 4", control.css(orders_link).sole.text.squish

    delete library_goals_path(locale: :fr), params: { kind: "theme", key: "roguelike" }, headers: STREAM
    assert_empty control.css("#set-album-goal a")
  end
end
