require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The capsule screen's reserve tabs: opening from the special tab spends that
# reserve alone, and going back after an opening shows the reserve left, not
# the one Turbo cached before.
class BoosterReservesTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

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

  test "on a phone, choosing the special tab after a standard hand shows the special capsule ahead and opens it" do
    resize_to(390, 844)
    cards = Array.new(Game::Pack::SIZE, catalog_card_seasons(:common_card_one).id)
    standard = create_pack(@player, cards:, available_at: 3.hours.ago)
    spare = create_pack(@player, cards:, available_at: 2.hours.ago)
    special = create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    visit booster_path(locale: :en)
    assert_selector ".booster[data-layout=phone]"

    find(".booster-canister").click
    assert_selector ".booster-tray__slot", count: 5, wait: 10
    click_on "Reveal all"
    assert_selector ".booster[data-status=complete]", wait: 15
    assert_no_selector ".booster[data-origin]"

    find(tab(:special)).click
    assert_selector "#{tab(:special)}[aria-selected=true]"
    assert_selector ".booster[data-reserve=special][data-origin=bonus]"
    find("button.booster__open").click

    eventually("the special capsule should be opened") { special.reload.opened? }
    assert_predicate standard.reload, :opened?
    assert_not_predicate spare.reload, :opened?
  end

  test "going back from the capsule screen shows the reserve left after opening, not the one cached before" do
    2.times { create_pack(@player, available_at: 3.hours.ago) }
    visit feed_path(locale: :en)
    assert_selector ".top-bar .packs-chip__count", text: "2"
    find(".top-bar a.packs-chip", match: :first).click
    find(".booster-canister").click
    assert_selector ".booster-card[data-dealt]", count: 5, wait: 10

    page.go_back

    assert_current_path feed_path(locale: :en)
    assert_selector ".top-bar .packs-chip__count", text: "1", wait: 0
  end
end
