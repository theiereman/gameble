require "test_helper"

class Accounts::UpdateSettingsTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def update(**settings) = Accounts::UpdateSettings.new.call(player: @player, **settings)

  test "a new player follows the system: no motion setting" do
    assert_nil @player.reduced_motion
  end

  test "it stores a reduced motion choice: reduced, an explicit no, and back to the system's" do
    assert_equal @player, update(reduced_motion: true).value!
    assert_equal true, @player.reload.reduced_motion

    assert update(reduced_motion: false).success?
    assert_equal false, @player.reload.reduced_motion

    assert update(reduced_motion: nil).success?
    assert_nil @player.reload.reduced_motion
  end

  test "a call without the setting leaves it as it was" do
    @player.update!(reduced_motion: true)

    assert update.success?

    assert_equal true, @player.reload.reduced_motion
  end

  [ "true", "on", 1, :reduced, "" ].each do |value|
    test "#{value.inspect} is no motion choice: invalid_setting, and nothing is written" do
      @player.update!(reduced_motion: true)

      assert_equal :invalid_setting, update(reduced_motion: value).failure
      assert_equal true, @player.reload.reduced_motion
    end
  end

  test "a missing player, or a banned one, fails with player_required" do
    [ nil, accounts_players(:banned), Accounts::Player.new(steam_id: "76561197960287930") ].each do |player|
      assert_equal :player_required, Accounts::UpdateSettings.new.call(player:, reduced_motion: true).failure
    end
    assert_nil accounts_players(:banned).reload.reduced_motion
  end

  test "it publishes no event" do
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      update(reduced_motion: true)
    end
  end

  test "the failures have their messages in both languages" do
    %i[player_required invalid_setting].each do |code|
      %i[en fr].each { |locale| assert I18n.exists?(Accounts::UpdateSettings.failure_key(code), locale), "#{code} in #{locale}" }
    end
  end
end
