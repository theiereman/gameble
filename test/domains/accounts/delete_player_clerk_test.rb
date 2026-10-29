require "test_helper"

class Accounts::DeletePlayerClerkTest < ActiveJob::TestCase
  setup { @player = accounts_players(:player) }

  test "one job is enqueued per distinct Clerk user of the player, and none for a player without one" do
    @player.identities.create!(provider: "discord", uid: "d-1", clerk_user_id: "user_a")
    @player.identities.create!(provider: "google", uid: "g-1", clerk_user_id: "user_a")
    @player.identities.create!(provider: "email", uid: "user_b", clerk_user_id: "user_b")

    assert_enqueued_jobs 2, only: Accounts::DeleteClerkUserJob do
      Accounts::DeletePlayer.new.call(player: @player).value!
    end
    assert_enqueued_with(job: Accounts::DeleteClerkUserJob, args: [ "user_a" ])
    assert_enqueued_with(job: Accounts::DeleteClerkUserJob, args: [ "user_b" ])
    assert_equal 0, Accounts::Identity.where(player_id: @player.id).count
  end

  test "a player with a Steam identity only enqueues nothing" do
    assert_no_enqueued_jobs(only: Accounts::DeleteClerkUserJob) { Accounts::DeletePlayer.new.call(player: @player).value! }
  end

  test "nothing is enqueued while an outer transaction is open or after it rolls back" do
    @player.identities.create!(provider: "discord", uid: "d-1", clerk_user_id: "user_a")

    ActiveRecord::Base.transaction do
      Accounts::DeletePlayer.new.call(player: @player).value!
      assert_enqueued_jobs 0, only: Accounts::DeleteClerkUserJob
      raise ActiveRecord::Rollback
    end

    assert_enqueued_jobs 0, only: Accounts::DeleteClerkUserJob
  end

  test "a refused deletion enqueues nothing" do
    @player.identities.create!(provider: "discord", uid: "d-1", clerk_user_id: "user_a")
    @player.update!(banned_at: Time.current)

    assert_no_enqueued_jobs(only: Accounts::DeleteClerkUserJob) { Accounts::DeletePlayer.new.call(player: @player) }
  end
end
