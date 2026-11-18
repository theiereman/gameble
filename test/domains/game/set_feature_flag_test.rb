require "test_helper"

class Game::SetFeatureFlagTest < ActiveSupport::TestCase
  setup do
    @administrator = accounts_players(:administrator)
  end

  def set(key: "duels", enabled: false, player: @administrator) = Game::SetFeatureFlag.new.call(player:, key:, enabled:)
  def events = Rails.configuration.event_store.read.of_type(Game::FeatureFlagSet).count

  test "an administrator switches a feature off and on, each change published" do
    assert_difference -> { events }, 1 do
      set(enabled: false).value!
    end
    assert_not_includes Game::EnabledFeatures.call, "duels"

    set(enabled: true).value!

    assert_includes Game::EnabledFeatures.call, "duels"
    assert_equal 1, Game::FeatureFlag.where(key: "duels").count
  end

  test "a feature never switched on is off" do
    Game::FeatureFlag.delete_all

    assert_empty Game::EnabledFeatures.call
  end

  test "a moderator or a player is refused, and so is a feature that does not exist" do
    assert_equal :administrator_required, set(player: accounts_players(:moderator)).failure
    assert_equal :administrator_required, set(player: accounts_players(:player)).failure
    assert_equal :unknown_feature, set(key: "teleport").failure
    assert_includes Game::EnabledFeatures.call, "duels"
  end
end
