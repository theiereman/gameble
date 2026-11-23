require "application_system_test_case"
require_relative "../support/game_sets"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/steam_sign_in"

# A player chasing a goal sees its missing cards under OBJECTIFS, then orders
# them one after the other from the goal's album, each form saying how the
# previous order went, and lands back on the album once the last is placed.
class GoalOrdersTest < ApplicationSystemTestCase
  include GameSets
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000)
    insert_set(%i[common_card_one uncommon_card_one].map { catalog_card_seasons(it).id }, { complete: 2 }, key: "roguelike", params: { "theme" => "roguelike" })
    Game::AddGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in
  end

  def place_order(price)
    fill_in "order-price", with: price
    find(".order-form__submit").click
  end

  test "a player orders a goal's two missing cards in a row from its album and the Collection stops suggesting them" do
    sign_in_through_the_site(@player)

    visit library_path(locale: :fr)
    assert_selector "#goals .goal-orders", text: "2 cartes à commander : Soldat de plomb · Collines vertes"

    visit library_set_path(locale: :fr, kind: "theme", key: "roguelike")
    find("#set-album-goal a", text: /passer des ordres · 2/i).click

    assert_selector "h1#order-form-heading", text: "Soldat de plomb"
    place_order("100")

    assert_selector "#order-chain-result", text: "Ordre passé sur Soldat de plomb : 100 PiCoins bloqués. Carte 1 sur 2."
    assert_selector "h1#order-form-heading:focus", text: "Collines vertes"
    place_order("100")

    assert_selector "#set-album-heading:focus"
    assert_selector "#toasts", text: "Carte 2 sur 2."
    assert_no_selector "#set-album-goal a", text: /passer des ordres/i

    visit library_path(locale: :fr)
    assert_selector "#goals .goal-row"
    assert_no_selector "#goals .goal-orders"
  end
end
