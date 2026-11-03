require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The daily capsule collected on the capsule screen, then opened by the same
# button.
class CapsuleFlowTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn
  OPEN = "button.booster__open".freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  teardown do
    reduce_motion(false)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def sign_in_to_capsules
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_current_path booster_path(locale: :en)
    assert_selector ".booster[data-layout]"
  end

  def opened_packs
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil)
  end

  test "the daily capsule is collected on the capsule screen, then opened by the same button" do
    reduce_motion(true)
    create_pack(@player, opened_at: 1.minute.ago)
    sign_in_to_capsules
    assert_selector "#{OPEN}[data-open=empty]"

    within("#booster-daily") do
      assert_text "DAILY CAPSULE"
      assert_text "READY"
      click_on "Collect"
    end

    assert_no_selector ".booster-daily", wait: 10
    assert_selector ".toast", text: I18n.t("daily_bonuses.create.collected", locale: :en, time: "%{time}").partition("%{time}").first.strip
    assert_selector ".booster-reserves__tab[data-reserve=special][aria-selected=true]", wait: 10
    assert_selector ".booster[data-reserve=special][data-phase=sealed]"
    find("#{OPEN}[data-open=open]").click

    assert_selector ".booster-card[data-dealt]", count: Game::Pack::BONUS_SIZE, wait: 10
    eventually("the daily capsule should be opened") { opened_packs.where(kind: "bonus").count == 1 }
  end
end
