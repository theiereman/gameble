require "test_helper"
require_relative "../support/steam_sign_in"

class PresenceTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 7, 15, 0)
  end

  def last_seen_jobs = enqueued_jobs.count { it["job_class"] == "Accounts::NoteLastSeenJob" }

  test "a GET enqueues the write without writing; the job writes the request's time" do
    travel_to(@now) do
      sign_in(@player)
      clear_enqueued_jobs
      travel 2.minutes

      assert_no_difference -> { @player.reload.last_seen_at.to_i } do
        assert_enqueued_with(job: Accounts::NoteLastSeenJob, args: [ @player.id, Time.current ]) { get friends_path(locale: :fr) }
      end
      assert_response :success

      perform_enqueued_jobs
      assert_equal Time.current, @player.reload.last_seen_at
    end
  end

  test "the sign-in notes the visit itself; within a minute nothing more is enqueued, after it the next request enqueues again" do
    travel_to(@now) do
      sign_in(@player)
      assert_equal @now, @player.reload.last_seen_at
      get home_path(locale: :fr)
      travel 59.seconds
      get friends_path(locale: :fr)
      assert_equal 0, last_seen_jobs

      travel 2.seconds
      get home_path(locale: :fr)
      assert_equal 1, last_seen_jobs

      travel 30.seconds
      get home_path(locale: :fr)
      assert_equal 1, last_seen_jobs

      travel 31.seconds
      get home_path(locale: :fr)
      assert_equal 2, last_seen_jobs
    end
  end

  test "an account seen within the minute, from another browser, is not enqueued again" do
    travel_to(@now) do
      @player.update_columns(last_seen_at: @now + 10.seconds)
      sign_in(@player)
      travel 30.seconds
      get home_path(locale: :fr)

      assert_equal 0, last_seen_jobs
    end
  end

  test "a visitor enqueues nothing" do
    get home_path(locale: :fr)
    get feed_path(locale: :fr)

    assert_equal 0, last_seen_jobs
  end
end
