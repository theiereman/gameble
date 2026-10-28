require "application_system_test_case"
require_relative "../support/steam_sign_in"

# The hub's daily booster panel: collected in one press,
# the claim answers in Turbo Stream, the canister arcs to the packs chip (and
# `gameble:bank-changed` follows), menu 01 counts one more booster and the
# panel stays, collected, with the countdown to 00:00 UTC; with a full
# reserve it stays ready and the capsule joins the special reserve. Under
# reduced motion no canister flies.
class DailyBonusTest < ApplicationSystemTestCase
  include SteamSignIn

  BADGE = ".hub-menu .menu-item[aria-keyshortcuts='1'] .menu-item__badge--standard".freeze
  SPECIAL_BADGE = ".hub-menu .menu-item[aria-keyshortcuts='1'] .menu-item__badge--special".freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  test "a player collects the daily booster from the hub" do
    Game::FillBank.new.call(player: @player).value!
    Game::OpenPack.new.call(player: @player).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_selector BADGE, text: "9", wait: 10
    take_screenshot

    within(".daily-booster") { click_on "Collect" }

    assert_text I18n.t("daily_bonuses.create.collected", locale: :en, time: "%{time}").partition("%{time}").first.strip
    assert_selector SPECIAL_BADGE, text: "1", wait: 10
    within(".daily-booster") do
      assert_text "COLLECTED"
      assert_text "NEXT IN"
      assert_text(/\A.*\d\d:\d\d:\d\d/m)
      assert_no_button "Collect"
    end
    assert_selector ".top-bar .packs-chip__count", text: "9"
    assert_selector ".top-bar .packs-chip__special-count", text: "1"
  end

  def watch_arc
    page.execute_script(<<~JS)
      window.arcSeen = false
      window.bankEvents = []
      new MutationObserver(() => { if (document.querySelector(".bonus-arc")) window.arcSeen = true })
        .observe(document.body, { childList: true })
      window.addEventListener("gameble:bank-changed", (event) => window.bankEvents.push(event.detail))
    JS
  end

  def sign_in_with_nine_boosters
    Game::FillBank.new.call(player: @player).value!
    Game::OpenPack.new.call(player: @player).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_selector BADGE, text: "9", wait: 10
  end

  test "the canister arcs to the packs chip, then the reserve is announced and the chip's count brightens" do
    sign_in_with_nine_boosters
    watch_arc

    within(".daily-booster") { click_on "Collect" }

    assert_selector SPECIAL_BADGE, text: "1", wait: 10
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("window.bankEvents.length") == 1 }
    assert page.evaluate_script("window.arcSeen"), "a canister should have flown"
    assert_no_selector ".bonus-arc"
    detail = page.evaluate_script("window.bankEvents[0]")
    assert_equal 9, detail["available"]
    assert_equal 1, detail["special"]
    assert_equal false, detail["reserveFull"]
    assert_equal 1, page.evaluate_script("window.bankEvents.length")
  end

  test "under reduced motion no canister flies, and the reserve is announced all the same" do
    sign_in_with_nine_boosters
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    watch_arc

    within(".daily-booster") { click_on "Collect" }

    assert_selector SPECIAL_BADGE, text: "1", wait: 10
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("window.bankEvents.length") == 1 }
    assert_not page.evaluate_script("window.arcSeen"), "no canister should fly"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  test "with the setting on, signed in, no canister flies either" do
    @player.update!(reduced_motion: true)
    sign_in_with_nine_boosters
    assert_selector "html[data-motion=reduced]", visible: :all
    watch_arc

    within(".daily-booster") { click_on "Collect" }

    assert_selector SPECIAL_BADGE, text: "1", wait: 10
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("window.bankEvents.length") == 1 }
    assert_not page.evaluate_script("window.arcSeen"), "no canister should fly"
  end

  test "a claim refused because another tab collected first: no canister, the panel as it is now, an alert" do
    sign_in_with_nine_boosters
    Game::CollectDailyBonus.new.call(player: @player).value!
    watch_arc

    within(".daily-booster") { click_on "Collect" }

    assert_text I18n.t("errors.game.already_collected", locale: :en, time: "%{time}").partition("%{time}").first.strip
    assert_selector ".daily-booster--collected"
    assert_selector SPECIAL_BADGE, text: "1", wait: 10
    sleep 0.8
    assert_not page.evaluate_script("window.arcSeen")
    assert_equal 0, page.evaluate_script("window.bankEvents.length")
  end

  test "with a full reserve, the panel stays ready and the capsule joins the special reserve" do
    Game::FillBank.new.call(player: @player).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_selector BADGE, text: "10", wait: 10

    within(".daily-booster") { click_on "Collect" }

    assert_selector ".daily-booster--collected", wait: 10
    assert_selector SPECIAL_BADGE, text: "1", wait: 10
    assert_selector BADGE, text: "10"
    take_screenshot
  end
end
