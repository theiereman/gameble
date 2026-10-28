require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The capsule screen's reserve tabs and the top bar's special chip: both tabs
# always shown, an empty one disabled with its reason, the screen opening on the
# special tab when no standard capsule is available, the opening drawing from
# the selected reserve alone, and the chips counting both reserves.
class BoosterReservesTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  def tab(name)
    "[role=tab][data-reserve=#{name}]"
  end

  test "with both kinds the standard tab is selected and opening a special capsule leaves the standard reserve alone" do
    standard = create_pack(@player, available_at: 3.hours.ago)
    special = create_pack(@player, kind: :bonus, available_at: 2.hours.ago)
    visit booster_path(locale: :en)

    assert_selector "#{tab(:standard)}[aria-selected=true]", text: "STANDARD · 1"
    assert_selector "#{tab(:special)}:not([disabled])", text: "SPECIAL · 1"
    find(tab(:special)).click
    assert_selector "#{tab(:special)}[aria-selected=true]"
    assert_selector ".booster__origin", text: "DAILY CAPSULE"
    find(".booster-canister").click

    assert_selector ".booster-card[data-dealt]", count: 3, wait: 10
    assert_predicate special.reload, :opened?
    assert_not_predicate standard.reload, :opened?
    assert_selector tab(:special) + "[disabled]", text: /SPECIAL · 0/
    assert_selector "#{tab(:standard)}[aria-selected=true]"
  end

  test "each origin's canister wears its look on the special tab and the standard tab drops it" do
    create_pack(@player, available_at: 3.hours.ago)
    create_pack(@player, kind: :reward, available_at: 2.hours.ago)
    visit booster_path(locale: :en)

    assert_no_selector "#booster[data-origin]"
    find(tab(:special)).click
    assert_selector "#booster[data-origin=reward]"
    assert_selector ".booster__origin", text: "GOAL REWARD"
    find(tab(:standard)).click
    assert_no_selector "#booster[data-origin]"
  end

  test "with no standard capsule the screen opens on the special tab and the standard tab says why it is off" do
    create_pack(@player, kind: :reward, available_at: 1.hour.ago)
    visit booster_path(locale: :en)

    assert_selector "#{tab(:special)}[aria-selected=true]"
    assert_selector "#{tab(:standard)}[disabled]", text: /No standard capsule yet/
    assert_selector ".booster__origin", text: "GOAL REWARD"
    assert_selector ".booster-canister"
  end

  test "on a phone the tabs are both reachable and fit the width" do
    create_pack(@player, available_at: 2.hours.ago)
    create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    original = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(*PHONE)
    visit booster_path(locale: :en)

    assert_selector tab(:special) + ":not([disabled])"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "no horizontal scroll"
  ensure
    page.driver.browser.manage.window.resize_to(original.width, original.height) if original
  end

  test "the special chip counts the special capsules, opens the special tab, and stays greyed at zero" do
    create_pack(@player, available_at: 2.hours.ago)
    visit home_path(locale: :en)

    assert_selector "#special-chip[aria-disabled=true]", text: /0\s+SPECIAL/i
    assert_selector ".top-bar .packs-chip__count", text: "1"

    create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    visit home_path(locale: :en)
    assert_selector "#special-chip:not([aria-disabled])", text: /1\s+SPECIAL/i
    find("#special-chip").click

    assert_selector "#{tab(:special)}[aria-selected=true]"
  end
end
