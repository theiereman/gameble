require "application_system_test_case"

# The signed-out attic (CAP-18, story 3.8): the chest and the daily bonus
# panel are visible, and pressing either starts the Steam sign-in, which
# brings the visitor back to the attic with their own chest.
class SignedOutAtticTest < ApplicationSystemTestCase
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/76561197960999999")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "a visitor sees the chest and the bonus panel, and enlists from the chest back to the attic" do
    visit home_path(locale: :en)

    assert_selector ".attic__bonus", text: "Daily bonus"
    within(".attic__bonus") { assert_button "Enlist through Steam to take it" }

    within(".attic__chest-action") { click_on "Enlist through Steam to open a pack" }

    assert_current_path home_path(locale: :en)
    within(".attic__chest-action") { assert_button "Open a pack (10)" }
    # Ten new packs make a full reserve: the panel asks to open one first (AD-7).
    within(".attic__bonus") do
      assert_text I18n.t("errors.game.reserve_full", locale: :en)
      assert_no_button "Take it"
    end
  end
end
