require "application_system_test_case"

# The daily bonus panel beside the attic chest (CAP-16): collected in one
# press, the chest counts one more pack and the panel is gone.
class DailyBonusTest < ApplicationSystemTestCase
  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "a player takes the daily bonus from the attic" do
    Game::FillBank.new.call(player: @player).value!
    visit home_path(locale: :en)
    click_on "Enlist through Steam"
    assert_button "Stand down"
    assert_button "Open a pack (10)"
    take_screenshot

    within(".attic__bonus") { click_on "Take it" }

    assert_text I18n.t("daily_bonuses.create.collected", locale: :en)
    assert_button "Open a pack (11)"
    assert_no_selector ".attic__bonus"
  end
end
