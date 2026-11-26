require "test_helper"

class Game::RevokeCodeContributionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @administrator = accounts_players(:administrator)
    @player = accounts_players(:player)
  end

  def revoke(staff: @administrator, player: @player) = Game::RevokeCodeContribution.new.call(staff:, player:)
  def grant = perform_enqueued_jobs { Game::GrantCodeContribution.new.call(staff: @administrator, player: @player).value! }
  def unlocked? = Game::AchievementUnlock.exists?(player_id: @player.id, achievement: "code_contribution")
  def events = Rails.configuration.event_store.read.of_type(Game::CodeContributionRevoked).count

  test "an administrator takes the marker and the achievement away, and can grant them again" do
    grant
    assert unlocked?

    assert_difference -> { events }, 1 do
      revoke.value!
    end

    assert_nil Game::PlayerState.find_by(player_id: @player.id).code_contribution_at
    assert_not unlocked?
    assert_equal 0, Game::AchievementProgress.call(@player, [ :code_contributions ]).fetch(:code_contributions)

    grant
    assert unlocked?
  end

  test "a player without the contribution is refused" do
    assert_no_difference -> { events } do
      assert_equal :code_contribution_not_granted, revoke.failure
    end
  end

  test "a moderator or a player is refused and the achievement stays" do
    grant
    [ accounts_players(:moderator), @player ].each do |staff|
      assert_equal :administrator_required, revoke(staff:).failure
    end
    assert unlocked?
  end
end
