require "application_system_test_case"
require_relative "../support/steam_sign_in"

# The one system test that goes through the sign-in screens: every other one
# signs its browser in directly with `sign_in_browser`.
class SteamSignInFlowTest < ApplicationSystemTestCase
  include SteamSignIn

  test "a visitor signs in through the top bar's link and the Steam button, then signs out" do
    mock_steam_sign_in(accounts_players(:player).steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    sign_out
    assert_signed_out
  end
end
