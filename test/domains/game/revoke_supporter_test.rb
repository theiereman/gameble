require "test_helper"

class Game::RevokeSupporterTest < ActiveSupport::TestCase
  setup do
    @administrator = accounts_players(:administrator)
    @player = accounts_players(:player)
  end

  def revoke(staff: @administrator, player: @player) = Game::RevokeSupporter.new.call(staff:, player:)
  def grant = Game::GrantSupporter.new.call(staff: @administrator, player: @player).value!
  def events = Rails.configuration.event_store.read.of_type(Game::SupporterRevoked).count

  test "an administrator removes the badge, which can be granted again" do
    grant

    assert_difference -> { events }, 1 do
      revoke.value!
    end

    assert_not Game::SupporterStatus.call(@player)
    grant
    assert Game::SupporterStatus.call(@player)
  end

  test "a player without the badge is refused" do
    assert_no_difference -> { events } do
      assert_equal :supporter_not_granted, revoke.failure
    end
  end

  test "a moderator or a player is refused and the badge stays" do
    grant
    [ accounts_players(:moderator), @player ].each do |staff|
      assert_equal :administrator_required, revoke(staff:).failure
    end
    assert Game::SupporterStatus.call(@player)
  end
end
