require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/live_duels"

# The DUELS tab and the trades tab's two sub-tabs, at phone width: Duels lists the player's decks and opens their
# editor, the trades tab opens the sub-tab last used, a visitor keeps two tabs; on desktop, menu 03 and 04.
class DuelsTest < ApplicationSystemTestCase
  include SteamSignIn
  include MarketSettings
  include LiveDuels

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def tab(name) = find(".tab-bar a.tab-bar__tab", text: name.upcase)

  test "the tutorial is open for a player who never duelled and folds under its title bar" do
    sign_in(@player)
    visit duels_path(locale: :en)

    assert_selector ".duel-tutorial__step", count: 4
    find(".duel-tutorial .hub-fold").click
    assert_no_selector ".duel-tutorial__step"
    assert_selector ".duel-tutorial__heading", text: "HOW A DUEL WORKS"
    find(".duel-tutorial .hub-fold").click
    assert_selector ".duel-tutorial__step", count: 4
  end

  test "a player with a complete deck trains against the bot, which plays its own moves" do
    complete_deck(@player, "Lea")
    complete_deck(accounts_players(:moderator), "Catalog")
    sign_in(@player)
    visit duels_path(locale: :en)

    click_button "Train against the bot"

    assert_selector ".duel-board__opponent", text: /bot/i
    duel = Game::Duel.sole
    assert duel.practice
    assert_current_path duel_path(locale: :en, token: duel.token)
  end

  test "on a phone, DUELS lists the decks and opens one's editor, which leads back to Duels" do
    first = Game::CreateDeck.new.call(player: @player, name: "Vieux briscards").value!
    Game::CreateDeck.new.call(player: @player, name: "Brouillon").value!
    sign_in(@player)
    resize_to(*PHONE)

    tab("Duels").click

    assert_current_path duels_path(locale: :en)
    assert_selector "h2#duel-decks-heading", text: "MY DECKS · 2 / 5"
    assert_selector ".deck-row__name", count: 2
    assert_equal [ "Vieux briscards", "Brouillon" ], all(".deck-row__name").map(&:text)
    assert_selector "a.deck-new", text: "NEW DECK"
    assert_selector ".tab-bar a.tab-bar__tab[aria-current=page]", text: "DUELS"

    find("a.deck-row", text: "Vieux briscards").click

    assert_current_path deck_path(locale: :en, token: first.token)
    assert_selector ".top-bar__phone-back", text: "DUELS"
    assert_selector ".tab-bar a.tab-bar__tab[aria-current=true]", text: "DUELS"
  end

  test "on a phone, the trades tab opens between friends, then the market once the player used it" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(@player)
    resize_to(*PHONE)

    tab("Trades").click

    assert_current_path trades_path(locale: :en)
    assert_selector "nav.exchanges-tabs a.exchanges-tabs__tab[aria-current=page]", text: "BETWEEN FRIENDS"

    find("nav.exchanges-tabs a.exchanges-tabs__tab", text: "MARKET").click

    assert_current_path market_path(locale: :en)
    assert_selector "nav.exchanges-tabs a.exchanges-tabs__tab[aria-current=page]", text: "MARKET"
    eventually("the market's heading should have the focus") { page.evaluate_script("document.activeElement.id") == "market-screen-heading" }
    eventually("the market should be kept") { Game::ExchangesTab.call(@player) == "market" }

    tab("Bridge").click
    assert_current_path home_path(locale: :en)
    tab("Trades").click

    assert_current_path market_path(locale: :en)
    assert_selector ".tab-bar a.tab-bar__tab[aria-current=page]", text: "TRADES"

    visit market_path(locale: :en)
    assert_selector ".market-screen"
  end

  test "on a phone, a visitor keeps two tabs and the market shows no sub-tab bar" do
    resize_to(*PHONE)

    visit library_cards_path(locale: :en)

    assert_selector ".tab-bar .tab-bar__label", count: 2
    assert_equal [ "HOME", "ALL CARDS" ], all(".tab-bar .tab-bar__label").map(&:text)

    visit market_path(locale: :en)
    assert_selector "h1"
    assert_no_selector "nav.exchanges-tabs"
    assert_no_selector ".tab-bar"
  end

  test "on desktop, the hub's menu reads 03 Trades and 04 Duels" do
    sign_in(@player)

    within(".hub-menu") do
      assert_selector "a.menu-item[aria-keyshortcuts='3'][href='/en/exchanges']", text: /03\s*TRADES/
      assert_selector "a.menu-item[aria-keyshortcuts='4'][href='/en/duels']", text: /04\s*DUELS/
    end
  end
end
