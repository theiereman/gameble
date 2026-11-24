require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The setting that turns the glow around a dealt card off, kept for the player and drawn by the stylesheet.
class RarityAuraSystemTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    sign_in_browser
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  def open_a_capsule
    create_pack(@player, available_at: 3.hours.ago)
    visit booster_path(locale: :en)
    find(".booster-canister").click
    assert_selector ".booster-card[data-dealt]", minimum: 3, wait: 10
  end

  def aura_displays = page.evaluate_script("Array.from(document.querySelectorAll('.booster-card__aura'), (aura) => getComputedStyle(aura).display)")

  test "a dealt card has its aura, and none once the player switched it off in the settings" do
    open_a_capsule
    assert_equal %w[block], aura_displays.uniq

    visit settings_path(locale: :en)
    within(".settings-row", text: /rarity aura/i) { find("button[name=rarity_aura][value=off]").click }
    assert_selector "html[data-rarity-aura=off]"
    assert_equal false, @player.reload.rarity_aura

    open_a_capsule
    assert_equal %w[none], aura_displays.uniq
  end
end
