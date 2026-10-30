require "test_helper"
require_relative "../../support/singleton_stub"

class Accounts::PushDevicesTest < ActiveSupport::TestCase
  include SingletonStub

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def register(player: @player, platform: "apple", token: "apns-token-1", locale: "fr")
    Accounts::RegisterPushDevice.new.call(player:, platform:, token:, locale:)
  end

  test "a player registers the device of their app, with its platform and locale" do
    device = register.value!

    assert_equal [ @player.id, "apple", "apns-token-1", "fr" ], [ device.player_id, device.platform, device.token, device.locale ]
    assert_equal [ device ], Accounts::PushDevicesOf.call([ @player.id ])
  end

  test "registering the same token again moves it to the player now signed in, without a second row" do
    register
    register(player: @other, locale: "en")

    device = Accounts::PushDevice.sole
    assert_equal [ @other.id, "en" ], [ device.player_id, device.locale ]
  end

  test "an unknown platform, an empty or oversized token and an unknown locale are refused" do
    assert_equal :invalid_push_device, register(platform: "windows").failure
    assert_equal :invalid_push_device, register(token: "").failure
    assert_equal :invalid_push_device, register(token: "a" * (Accounts::PushDevice::TOKEN_LENGTH + 1)).failure
    assert_equal :invalid_push_device, register(locale: "de").failure
    assert_equal :invalid_push_device, register(platform: [ "apple" ]).failure
    assert_equal 0, Accounts::PushDevice.count
  end

  test "a visitor or a banned player cannot register a device" do
    assert_equal :player_required, register(player: nil).failure
    assert_equal :player_required, register(player: accounts_players(:banned)).failure
  end

  test "forgetting a token drops its device" do
    register

    assert Accounts::ForgetPushDevice.new.call(token: "apns-token-1").success?
    assert_equal 0, Accounts::PushDevice.count
    assert_equal :invalid_push_device, Accounts::ForgetPushDevice.new.call(token: nil).failure
  end

  test "the devices of a banned or deleted player are not read" do
    register
    @player.update!(banned_at: Time.current)

    assert_empty Accounts::PushDevicesOf.call([ @player.id ])
  end

  test "deleting the account deletes its devices" do
    register

    assert Accounts::DeletePlayer.new.call(player: @player).success?
    assert_equal 0, Accounts::PushDevice.count
  end

  test "a token the push service rejects is forgotten" do
    device = register.value!
    rejecting = Object.new.tap { |service| service.define_singleton_method(:push) { |_notification| raise ActionPushNative::TokenError } }

    stub_singleton(ActionPushNative, :service_for, ->(*) { rejecting }) { device.push(ApplicationPushNotification.new(title: "Hi")) }

    assert_equal 0, Accounts::PushDevice.count
  end
end
