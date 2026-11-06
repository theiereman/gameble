require "application_system_test_case"
require_relative "../support/steam_sign_in"

class NativeAppSystemTest < ApplicationSystemTestCase
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  APP = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
    "Hotwire Native iOS; Turbo Native iOS; bridge-components: [haptics push-permission share]".freeze

  setup do
    player = accounts_players(:player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    resize_to(*PHONE)
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: APP)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: "")
  end

  test "in the app a screen has one header and gives no height to a web tab bar" do
    visit friends_path(locale: :en)

    assert_selector "html[data-native-app]", visible: :all
    assert_no_selector ".tab-bar", visible: :all
    assert_selector "header.top-bar", count: 1
    assert_equal "0px", page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--tabbar-height').trim()")
  end

  test "a sheet's content scrolls down to the bottom edge of a screen with a home indicator" do
    page.driver.browser.execute_cdp("Emulation.setSafeAreaInsetsOverride", insets: { top: 47, bottom: 34, left: 0, right: 0 })
    visit library_cards_path(locale: :en)
    first("[data-bottom-sheet-opens]").click
    assert_selector ".bottom-sheet[open] .bottom-sheet__body"

    gap, room = page.evaluate_script(<<~JS)
      (async () => {
        const body = document.querySelector(".bottom-sheet[open] .bottom-sheet__body")
        await Promise.all(body.closest("dialog").getAnimations({ subtree: true }).map((animation) => animation.finished))
        return [window.innerHeight - body.getBoundingClientRect().bottom, parseFloat(getComputedStyle(body).paddingBottom)]
      })()
    JS
    assert_in_delta 0, gap, 1
    assert_operator room, :>=, 34
  ensure
    page.driver.browser.execute_cdp("Emulation.setSafeAreaInsetsOverride", insets: { top: 0, bottom: 0, left: 0, right: 0 })
  end

  test "in the app a sub-screen keeps its way back" do
    visit feed_path(locale: :en)

    assert_selector "header.top-bar .top-bar__phone-back"
  end
end
