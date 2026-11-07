require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class NativeAppSystemTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  APP = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
    "Hotwire Native iOS; Turbo Native iOS; bridge-components: [haptics push-permission share top-bar]".freeze

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

  test "in the app a screen has one header, out of sight, and leaves the bar's height free" do
    visit friends_path(locale: :en)

    assert_selector "html[data-native-app][data-native-bar]", visible: :all
    assert_no_selector ".tab-bar", visible: :all
    assert_selector "header.top-bar", count: 1, visible: :hidden
    assert_equal "0px", page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--tabbar-height').trim()")
    assert_equal "56px", page.evaluate_script("getComputedStyle(document.body).paddingTop")
    assert_equal [ 0, 0 ], page.evaluate_script("(() => { const box = document.querySelector('header.top-bar').getBoundingClientRect(); return [box.width, box.height] })()")
  end

  test "an app that does not declare the native bar keeps the page's bar" do
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: APP.sub(" top-bar", ""))
    visit friends_path(locale: :en)

    assert_selector "html[data-native-app]", visible: :all
    assert_no_selector "html[data-native-bar]", visible: :all
    assert_selector "header.top-bar .top-bar__end"
    assert_equal "0px", page.evaluate_script("getComputedStyle(document.body).paddingTop")
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

  test "in the app a panel's link goes to the app's navigation, and the bar reads its values again" do
    visit trades_path(locale: :en)
    connect_as_the_app

    tap_on_the_bar "menu"
    within("#phone-menu-panel") { click_link "Settings" }

    assert_no_selector "#phone-menu-panel:popover-open"
    assert_current_path trades_path(locale: :en)
    eventually("the app should be asked for the settings") { sent_to_app.include?("/en/settings") }

    count = standard_count
    now = Time.current
    create_pack(accounts_players(:player), available_at: now - 1.minute)
    execute_script("window.dispatchEvent(new CustomEvent('gameble:screen-shown'))")

    eventually("the bar should show the new capsule") { standard_count == count + 1 }
  end

  test "a tap on the native bar opens the panel right under it, and a second tap closes it" do
    visit friends_path(locale: :en)
    connect_as_the_app

    tap_on_the_bar "bell"

    assert_selector "#bell-panel:popover-open"
    top, right_gap = page.evaluate_script(<<~JS)
      (() => {
        const box = document.getElementById("bell-panel").getBoundingClientRect()
        return [box.top, window.innerWidth - box.right]
      })()
    JS
    assert_in_delta 56 + 8, top, 8
    assert_operator right_gap, :>=, 0

    tap_on_the_bar "bell"

    assert_no_selector "#bell-panel:popover-open"
  end

  test "the native bar's bell and menu open their panels on a sub-screen too" do
    visit settings_path(locale: :en)
    assert_no_selector "header.top-bar.top-bar--top-level", visible: :all
    connect_as_the_app

    tap_on_the_bar "bell"
    assert_selector "#bell-panel:popover-open"

    tap_on_the_bar "menu"
    assert_selector "#phone-menu-panel:popover-open"
  end

  test "the avatar's menu opens under the native bar, trades places with the bell, and closes when the bar hides" do
    visit friends_path(locale: :en)
    connect_as_the_app

    tap_on_the_bar "bell"
    assert_selector "#bell-panel:popover-open"
    tap_on_the_bar "menu"

    assert_no_selector "#bell-panel:popover-open"
    assert_selector "#phone-menu-panel:popover-open"
    assert_link "Settings"
    assert_operator page.evaluate_script("document.getElementById('phone-menu-panel').getBoundingClientRect().top"), :>=, 56

    tap_on_the_bar nil

    assert_no_selector "#phone-menu-panel:popover-open"
  end

  test "a panel closes when its screen comes back on view" do
    visit friends_path(locale: :en)
    connect_as_the_app

    tap_on_the_bar "menu"
    assert_selector "#phone-menu-panel:popover-open"
    execute_script("window.dispatchEvent(new CustomEvent('gameble:screen-shown'))")

    assert_no_selector "#phone-menu-panel:popover-open"
  end

  test "the page reports the bar's counts, bell and avatar, and again when they change" do
    visit friends_path(locale: :en)
    connect_as_the_app

    report = top_bar_reports.last
    assert_equal standard_count.to_s, report["standard"].delete(",")
    assert_match(/\A\d+\z/, report["special"])
    assert report.key?("bell")
    assert report.key?("menuBadge")
    capsules = report["standard"].delete(",").to_i + report["special"].to_i
    assert_equal (capsules.positive? ? capsules.to_s : ""), report["capsules"]
    assert report.key?("friends")
    assert report.key?("trades")
    assert_match %r{\Adata:image/png;base64,}, report["avatar"]
    size = page.evaluate_script(<<~JS, report["avatar"])
      new Promise((resolve) => {
        const image = new Image()
        image.onload = () => resolve([image.naturalWidth, image.naturalHeight])
        image.src = arguments[0]
      })
    JS
    assert_equal [ 108, 108 ], size

    execute_script("document.querySelector('.bank-counter__item:not(.bank-counter__item--special) .bank-counter__count').textContent = '77'")
    eventually("the page should report the new count") { top_bar_reports.last["standard"] == "77" }
    reports = top_bar_reports
    first_with_it = reports.index { it["standard"] == "77" }
    assert_operator first_with_it, :>, 0
    assert_not_equal "77", reports[first_with_it - 1]["standard"]
  end

  test "a screen restored from the cache reports the server's counts, never the ones it was cached with" do
    visit library_cards_path(locale: :en)
    connect_as_the_app
    server_count = standard_count.to_s
    execute_script("document.querySelector('.bank-counter__item:not(.bank-counter__item--special) .bank-counter__count').textContent = '77'")
    eventually("the page should report the count it will be cached with") { top_bar_reports.last["standard"] == "77" }

    execute_script("Turbo.visit(#{trades_path(locale: :en).to_json})")
    assert_current_path trades_path(locale: :en)
    execute_script("window.sentToApp = []")
    page.go_back
    assert_current_path library_cards_path(locale: :en)

    eventually("the restored screen should report the server's count") { top_bar_reports.last&.fetch("standard") == server_count }
    assert_not_includes top_bar_reports.map { it["standard"] }, "77"
  end

  test "the page tells the app when a dialog opens and closes" do
    visit library_cards_path(locale: :en)
    connect_as_the_app
    eventually("the page should say no dialog is open") { dialog_reports.last == false }

    first("[data-bottom-sheet-opens]").click
    eventually("the page should say a dialog is open") { dialog_reports.last == true }

    execute_script("document.querySelector('dialog[open]').close()")
    eventually("the page should say the dialog closed") { dialog_reports.last == false }
  end

  test "the bell's badge is reported empty while hidden" do
    visit friends_path(locale: :en)
    connect_as_the_app

    execute_script(<<~JS)
      const count = document.querySelector("[data-bell-target=count]")
      count.textContent = "3"
      count.hidden = false
    JS
    eventually("the page should report the badge") { top_bar_reports.last["bell"] == "3" }

    execute_script('document.querySelector("[data-bell-target=count]").hidden = true')
    eventually("the page should report no badge") { top_bar_reports.last["bell"] == "" }
  end

  test "with the native bar the capsule screen fits the web view without a scroll" do
    visit booster_path(locale: :en)

    assert_selector ".booster[data-layout='phone']"
    room, content = page.evaluate_script("[window.innerHeight, document.documentElement.scrollHeight]")
    assert_operator content, :<=, room
  end

  test "with the native bar the collection's progress heads the page, below the bar, and opens its legend" do
    visit library_path(locale: :en)

    assert_selector ".native-status .collection-status"
    assert_no_selector ".top-bar__end .collection-status", visible: :all
    assert_operator page.evaluate_script("document.querySelector('.native-status .collection-status').getBoundingClientRect().top"), :>=, 56
    find(".native-status .collection-status").click
    assert_selector "#rarity-legend:popover-open"
  end

  test "in the app no screen carries a way back of its own" do
    [ library_cards_path(locale: :en), friends_path(locale: :en), me_path(locale: :en), feed_path(locale: :en) ].each do |path|
      visit path

      assert_no_selector ".top-bar__previous, .top-bar__phone-back, .top-bar__start", visible: :all
    end
  end

  private
    # The controller reports as it connects, so a first report also says it now listens for the bar's taps.
    def connect_as_the_app
      execute_script(<<~JS)
        window.sentToApp = []
        window.HotwireNative.web.setAdapter({
          platform: "ios",
          supportedComponents: ["top-bar"],
          supportsComponent: () => true,
          receive: (message) => window.sentToApp.push(JSON.stringify(message))
        })
      JS
      eventually("the page should report the bar's state") { top_bar_reports.any? }
    end

    def tap_on_the_bar(panel)
      execute_script(<<~JS, panel)
        window.dispatchEvent(new CustomEvent("gameble:top-bar-panel", { detail: { panel: arguments[0] } }))
      JS
    end

    def sent_to_app
      evaluate_script("window.sentToApp.join()")
    end

    def top_bar_reports
      evaluate_script("window.sentToApp").map { JSON.parse(it) }.select { it["event"] == "state" }.map { it["data"] }
    end

    def standard_count
      evaluate_script("document.querySelector('.bank-counter__item .bank-counter__count').textContent").delete(",").to_i
    end

    def dialog_reports
      evaluate_script("window.sentToApp").map { JSON.parse(it) }.select { it["event"] == "dialog" }.map { it.dig("data", "open") }
    end
end
