require "application_system_test_case"
require_relative "../support/game_packs"

# The hub, "Pont de commandement" (story 8.2): its layout on a desktop and
# two phones, signed in and out; the sign-in panel and its focus; the menu's
# number keys and the item focused on the way back; landing on the hub after
# signing in and out.
class HubTest < ApplicationSystemTestCase
  include GamePacks

  PHONES = { "390" => [ 390, 844 ], "360" => [ 360, 740 ] }.freeze

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    resize_to(*SCREEN_SIZE)
  end

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
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
    create_pack(@player, cards: fixture_tier_ids.first(4) + fixture_tier_ids.first(1), opened_at: 1.hour.ago)
    2.times { create_pack(@player) }
    sign_in

    assert_selector ".hub-menu .menu-item", count: 6
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

  test "on a desktop, a visitor sees the menu and the invitation" do
    visit home_path(locale: :fr)

    assert_selector ".hub-menu .menu-item", count: 6
    assert_selector ".hub-invitation", text: "Vos jeux Steam, en cartes à collectionner."
    assert_no_selector ".daily-booster"
    assert_selector ".top-bar .steam-sign-in__button"
    assert_no_sideways_scroll
    take_screenshot
  end

  PHONES.each do |name, size|
    test "on a #{name}px phone, one column without the menu, signed out then in, and the sign-in panel as a bottom sheet" do
      resize_to(*size)
      visit home_path(locale: :en)

      assert_no_selector ".hub-menu"
      assert_selector ".tab-bar"
      assert_selector ".hub-invitation"
      assert_no_sideways_scroll
      take_screenshot

      click_on "Open my first boosters"
      assert_selector "dialog#sign-in-panel[open]"
      assert_selector "#sign-in-panel .modal__handle"
      # The sheet rises from below, then rests on the bottom edge.
      height = page.evaluate_script("window.innerHeight")
      bottom = -> { page.evaluate_script("Math.round(document.querySelector('#sign-in-panel').getBoundingClientRect().bottom)") }
      Timeout.timeout(3) { sleep 0.05 until (bottom.call - height).abs <= 1 }
      take_screenshot
      find("#sign-in-panel .modal__close").click
      assert_no_selector "dialog#sign-in-panel[open]"

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

  test "the sign-in panel opens from menu 01 and closes by its close button, Esc and the scrim, focus back on the opener" do
    visit home_path(locale: :en)

    item("1").click
    assert_selector "dialog#sign-in-panel[open]", text: "SIGN IN TO PLAY"
    assert focused?("#sign-in-panel .steam-sign-in__button"), "the official image should take the focus first"
    take_screenshot
    find("#sign-in-panel .modal__close").click
    assert_no_selector "dialog#sign-in-panel[open]"
    assert focused?(".hub-menu .menu-item[aria-keyshortcuts='1']"), "the focus should return to menu 01"

    item("1").send_keys(:enter)
    assert_selector "dialog#sign-in-panel[open]"
    find("#sign-in-panel .steam-sign-in__button").send_keys(:escape)
    assert_no_selector "dialog#sign-in-panel[open]"
    assert focused?(".hub-menu .menu-item[aria-keyshortcuts='1']"), "the focus should return to menu 01"

    within(".hub-invitation") { click_on "Open my first boosters" }
    assert_selector "dialog#sign-in-panel[open]"
    # A click at the top left corner of the window lands on the scrim.
    page.driver.browser.action.move_to_location(5, 5).click.perform
    assert_no_selector "dialog#sign-in-panel[open]"
    assert focused?(".hub-invitation .button--primary"), "the focus should return to the invitation's button"
    assert_selector ".top-bar .steam-sign-in__button"
  end

  test "the sign-in panel opens from a card page's invitation, and signing in from it lands on the hub" do
    create_pack(@player)
    visit card_path(locale: :en, slug: "portal")

    within(".card-detail__invitation") { click_on "Open my first boosters" }
    find("#sign-in-panel .modal__close").send_keys(:escape)
    assert_no_selector "dialog#sign-in-panel[open]"
    assert focused?(".card-detail__invitation .button"), "the focus should return to the invitation's button"

    within(".card-detail__invitation") { click_on "Open my first boosters" }
    within("dialog#sign-in-panel[open]") { find(".steam-sign-in__button").click }

    assert_signed_in
    assert_current_path home_path(locale: :en)
    assert_equal "1", focused_item
  end

  test "keys 1 to 6 act only inside the menu, never on a disabled item; the item used is focused on the way back" do
    create_pack(@player)
    sign_in
    # Signing in focuses menu 01.
    assert_equal "1", focused_item
    take_screenshot

    item("1").send_keys("3")
    assert_current_path home_path(locale: :en)
    find("body").send_keys("2")
    assert_current_path home_path(locale: :en)

    item("1").send_keys("2")
    assert_current_path library_path(locale: :en)

    click_on "Bridge"
    assert_current_path home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_equal "2", focused_item

    # Only once: a later visit focuses nothing.
    visit home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_nil focused_item
  end

  test "a sign-in focuses menu 01 even when another item was used before it" do
    create_pack(@player)
    visit home_path(locale: :en)
    item("2").click
    assert_current_path library_path(locale: :en)
    assert_equal "2", page.evaluate_script("sessionStorage.getItem('gameble:hub-menu-item')")

    click_steam_sign_in
    assert_signed_in
    assert_current_path home_path(locale: :en)
    assert_equal "1", focused_item
    assert_nil page.evaluate_script("sessionStorage.getItem('gameble:hub-menu-item')"), "the stored item is consumed"
  end

  test "signing out is a full page load that lands on the signed-out hub" do
    sign_in
    page.execute_script("window.sameDocument = true")

    sign_out

    assert_signed_out
    assert_current_path home_path(locale: :en)
    assert_selector ".hub-invitation"
    assert_text I18n.t("sessions.destroy.farewell", locale: :en)
    assert_nil page.evaluate_script("window.sameDocument"), "signing out should load a new page"
  end
end
