require "test_helper"
require_relative "../support/steam_sign_in"

class PushDevicesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup { @player = accounts_players(:player) }

  test "a signed-in app registers its device in the locale it is browsing" do
    sign_in(@player)

    post push_devices_path(locale: :fr), params: { platform: "google", token: "fcm-token" }

    assert_response :no_content
    device = Accounts::PushDevice.sole
    assert_equal [ @player.id, "google", "fcm-token", "fr" ], [ device.player_id, device.platform, device.token, device.locale ]
  end

  test "a malformed device is refused" do
    sign_in(@player)

    post push_devices_path(locale: :en), params: { platform: "nokia", token: "x" }

    assert_response :unprocessable_entity
    assert_equal 0, Accounts::PushDevice.count
  end

  test "a visitor cannot register a device" do
    post push_devices_path(locale: :en), params: { platform: "apple", token: "apns-token" }

    assert_equal 0, Accounts::PushDevice.count
  end

  test "signing out forgets the device this session registered, so it no longer gets the player's notifications" do
    sign_in(@player)
    post push_devices_path(locale: :en), params: { platform: "apple", token: "apns-token" }

    delete session_path

    assert_equal 0, Accounts::PushDevice.count
  end
end
