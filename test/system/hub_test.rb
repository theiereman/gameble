require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The hub, "Pont de commandement": its layout on a desktop and
# two phones, signed in and out; the sign-in panel and its focus; the menu's
# number keys and the item focused on the way back; landing on the hub after
# signing in and out.
class HubTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONES = { "390" => [ 390, 844 ], "360" => [ 360, 740 ] }.freeze
  LIVE_RED = "rgb(179, 0, 27)".freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  def focused_item
    page.evaluate_script("document.activeElement.getAttribute('aria-keyshortcuts')")
  end

  def focused?(selector)
    page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def item(key)
    find(".hub-menu .menu-item[aria-keyshortcuts='#{key}']")
  end

  test "on a desktop, a player sees the menu, the showcase, the daily panel and the sets in three columns" do
    gained = 1.hour.ago.change(usec: 0)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1, last_gained_at: gained)
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: catalog_sets(:valve_one).id, tier: "complete", reached_by: "trade",
      reached_at: gained, created_at: gained, updated_at: gained } ])
    2.times { create_pack(@player) }
    sign_in

    assert_selector ".hub-menu .menu-item", count: 9
    assert_selector ".hub-showcase .card--xl"
    assert_selector ".daily-booster"
    assert_selector ".hub-sets .set-row"
    menu, showcase, sets = %w[.hub-menu .hub-showcase .hub-sets].map do |selector|
      page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().left")
    end
    assert_operator menu, :<, showcase
    assert_operator showcase, :<, sets
    assert_no_sideways_scroll
    take_screenshot
  end

  def rect(selector)
    page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); " \
      "return { top: r.top, bottom: r.bottom, left: r.left, width: r.width } })()").transform_keys(&:to_sym)
  end

  def scroll_to_end
    page.execute_script("window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'instant' })")
  end

  def page_bottom = page.evaluate_script("document.documentElement.scrollHeight - window.scrollY")

  def live_square_colour = page.evaluate_script("getComputedStyle(document.querySelector('#live-ticker .live-marker__dot')).backgroundColor")

  test "on a desktop, the LIVE ticker is a full-width band along the bottom of the hub, under its columns" do
    create_pack(@player, cards: fixture_tier_ids.first(4) + fixture_tier_ids.first(1), opened_at: 1.hour.ago)
    sign_in

    assert_selector "#live-ticker .ticker__inner"
    assert_selector ".hub-sets .set-row"
    ticker = rect("#live-ticker")
    assert_operator rect(".top-bar")[:bottom], :<=, rect(".hub")[:top]
    %w[.hub__kicker .hub-menu .hub-showcase #community-goal .hub-sets].each do |column|
      assert_operator rect(column)[:bottom], :<=, ticker[:top], "#{column} should sit above the ticker"
    end
    assert_equal 0, ticker[:left]
    window_width = page.evaluate_script("document.documentElement.clientWidth")
    assert_in_delta window_width, ticker[:width], 1
    assert_equal 0, rect("#live-ticker .live-marker")[:left], "the LIVE marker should sit on the window's left edge"
    scroller = rect("#live-ticker .ticker__window")
    assert_in_delta window_width, scroller[:left] + scroller[:width], 1, "the scrolling line should reach the window's right edge"
    assert_equal LIVE_RED, live_square_colour

    scroll_to_end
    ticker = rect("#live-ticker")
    assert_in_delta page_bottom, ticker[:bottom], 1, "the ticker should end the page"
    assert_operator rect(".app-version")[:bottom], :<=, ticker[:top], "the version label should clear the ticker"
    assert_operator rect(".app-version__legal")[:bottom], :<=, ticker[:top], "the legal link should clear the ticker"
    assert_operator rect("#toasts")[:bottom], :<=, ticker[:top], "the toasts should clear the ticker"
    assert_no_sideways_scroll
    take_screenshot
  end

  test "on a phone, the LIVE ticker is the last block of the hub, above the tab bar" do
    create_pack(@player, cards: fixture_tier_ids.first(4) + fixture_tier_ids.first(1), opened_at: 1.hour.ago)
    resize_to(*PHONES.fetch("390"))
    sign_in

    assert_selector ".hub-sets .set-row"
    assert_selector "#live-ticker .ticker__inner"
    assert_operator rect(".hub-sets")[:bottom], :<=, rect("#live-ticker")[:top]
    assert_equal 20, rect("#live-ticker .live-marker")[:left], "the phone ticker should keep its gutter"
    assert_equal LIVE_RED, live_square_colour

    scroll_to_end
    ticker = rect("#live-ticker")
    tab_bar = rect(".tab-bar")
    assert_in_delta tab_bar[:top], ticker[:bottom], 1, "the ticker should rest on the tab bar"
    assert_in_delta page_bottom, tab_bar[:bottom], 1, "nothing should scroll under the tab bar after the ticker"
    assert_operator rect(".app-version")[:bottom], :<=, ticker[:top], "the version label should clear the ticker"
    assert_operator rect(".app-version__legal")[:bottom], :<=, ticker[:top], "the legal link should clear the ticker"
    assert_no_sideways_scroll
    take_screenshot
  end

  test "the showcase's card, still held, is reposted from under it with a toast" do
    create_pack(@player, cards: fixture_tier_ids.first(4) + fixture_tier_ids.first(1), opened_at: 1.hour.ago)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
    sign_in

    within(".hub-showcase") { click_on "Repost" }

    assert_selector "#toasts .toast--notice", text: /card reposted to the feed\./i
    assert_selector ".hub-showcase button", text: "REPOST"
    assert_equal [ catalog_card_seasons(:portal_one).id ], Game::FeedEntry.where(kind: "repost").pluck(:card_season_id)
  end

  test "on a desktop, a visitor sees the landing instead of the hub" do
    visit home_path(locale: :fr)

    assert_current_path landing_path(locale: :fr)
    assert_selector ".landing-hero__hook", text: "Des jeux ont été perdus. La Confrérie part les retrouver. Rejoignez-la."
    assert_no_selector ".hub-menu"
    assert_no_selector ".daily-booster"
    assert_selector ".top-bar .steam-sign-in__button"
    assert_no_sideways_scroll
    take_screenshot
  end

  PHONES.each do |name, size|
    test "on a #{name}px phone, one column without the menu, signed out then in" do
      resize_to(*size)
      visit home_path(locale: :en)

      assert_current_path landing_path(locale: :en)
      assert_no_selector ".hub-menu"
      assert_selector ".landing-hero"
      assert_no_sideways_scroll
      take_screenshot

      create_pack(@player)
      click_steam_sign_in
      assert_signed_in
      # The menu is hidden: the heading takes the focus a sign-in asks for.
      assert focused?("h1.hub__title"), "the heading should hold the focus"
      order = %w[.hub__kicker .hub-showcase .daily-booster .hub-sets].map do |selector|
        page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().top")
      end
      assert_equal order.sort, order, "kicker, showcase, daily panel, sets, top to bottom"
      assert_no_sideways_scroll
      take_screenshot
    end
  end

  test "a visitor follows the terms link beside the sign-in button to the legal page's terms" do
    visit home_path(locale: :en)

    within(".landing-hero__action") do
      assert_text "By signing in you accept the terms of use and acknowledge the privacy notice."
      click_on "terms of use"
    end

    assert_current_path %r{/en/legal#legal-terms\z}, url: true
    assert_selector "h1#legal-heading", text: /LEGAL NOTICE AND PRIVACY/i
    assert_selector "h2#legal-terms", text: /TERMS OF USE/i
    assert_text "By signing in with Steam, you accept these terms."
  end

  test "on a phone, a visitor taps the legal link beside the version and reads the legal page" do
    resize_to(*PHONES.fetch("390"))
    visit home_path(locale: :fr)

    find(".app-version__legal", text: "Mentions légales").click

    assert_current_path "/fr/legal"
    assert_selector "h1#legal-heading", text: /MENTIONS LÉGALES ET CONFIDENTIALITÉ/i
  end

  test "on a desktop, a player follows the legal link beside the version to the legal page" do
    sign_in

    click_on "Legal notice"

    assert_current_path "/en/legal"
    assert_selector "h1#legal-heading", text: /LEGAL NOTICE AND PRIVACY/i
  end

  test "signing in from a card page's pitch lands on the hub" do
    create_pack(@player)
    visit card_path(locale: :en, slug: "portal")

    within(".public-card__pitch") { click_on "Open my first capsules" }

    assert_signed_in
    assert_current_path home_path(locale: :en)
    assert_equal "1", focused_item
  end

  test "number keys act only inside the menu, never on a disabled item; the item used is focused on the way back" do
    create_pack(@player)
    sign_in
    # Signing in focuses menu 01.
    assert_equal "1", focused_item
    take_screenshot

    item("1").send_keys("0")
    assert_current_path home_path(locale: :en)
    find("body").send_keys("2")
    assert_current_path home_path(locale: :en)

    item("1").send_keys("2")
    assert_current_path library_path(locale: :en)

    find(".top-bar__home").click
    assert_current_path home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_equal "2", focused_item

    # Only once: a later visit focuses nothing.
    visit home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_nil focused_item
  end

  test "menu 01 opens the booster screen; back on the bridge after its last booster, menu 01 is focused, its badge greyed" do
    create_pack(@player, cards: fixture_tier_ids)
    sign_in

    item("1").click
    assert_current_path booster_path(locale: :en)
    find(".booster-canister").click
    assert_selector ".booster-card[data-dealt]", count: 5, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    find(".top-bar__home").click
    assert_current_path home_path(locale: :en)
    assert_selector ".hub-menu .menu-item[aria-keyshortcuts='1']:not([aria-disabled]) .menu-item__badge--zero", text: "0"
    assert_equal "1", focused_item
  end

  test "a sign-in focuses menu 01 even when another item was used before it" do
    create_pack(@player)
    sign_in
    item("2").click
    assert_current_path library_path(locale: :en)
    assert_equal "2", page.evaluate_script("sessionStorage.getItem('gameble:hub-menu-item')")
    sign_out
    assert_signed_out

    click_steam_sign_in
    assert_signed_in
    assert_current_path home_path(locale: :en)
    assert_equal "1", focused_item
    assert_nil page.evaluate_script("sessionStorage.getItem('gameble:hub-menu-item')"), "the stored item is consumed"
  end

  test "signing out is a full page load that lands on the landing" do
    sign_in
    page.execute_script("window.sameDocument = true")

    sign_out

    assert_signed_out
    assert_current_path landing_path(locale: :en)
    assert_selector ".landing-hero"
    assert_text I18n.t("sessions.destroy.farewell", locale: :en)
    assert_nil page.evaluate_script("window.sameDocument"), "signing out should load a new page"
  end
end
