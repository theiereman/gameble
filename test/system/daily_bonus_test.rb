require "application_system_test_case"

# The hub's daily booster panel (CAP-16): collected in one press, menu 01
# counts one more booster and the panel is gone; with a full reserve (AD-7)
# it says so and its button is disabled.
class DailyBonusTest < ApplicationSystemTestCase
  BADGE = ".hub-menu .menu-item[aria-keyshortcuts='1'] .menu-item__badge".freeze

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "a player collects the daily booster from the hub" do
    Game::FillBank.new.call(player: @player).value!
    Game::OpenPack.new.call(player: @player).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_selector BADGE, text: "9"
    take_screenshot

    within(".daily-booster") { click_on "Collect" }

    assert_text I18n.t("daily_bonuses.create.collected", locale: :en)
    assert_selector BADGE, text: "10"
    assert_no_selector ".daily-booster"
  end

  test "with a full reserve, the panel says to open a booster first" do
    Game::FillBank.new.call(player: @player).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_selector BADGE, text: "10"

    within(".daily-booster") do
      assert_text "RESERVE FULL"
      assert_text "Open a booster to collect today's."
      assert_button "Collect", disabled: true
    end
    take_screenshot
  end
end
