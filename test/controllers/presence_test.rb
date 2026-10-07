require "test_helper"

# Last seen (CAP-21, AD-11, AD-24, story 5.3): a signed-in player's request
# enqueues the last-seen write at most once a minute; the request itself,
# a GET above all, writes no row.
class PresenceTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 7, 15, 0)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player = @player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
  end

  def last_seen_jobs = enqueued_jobs.count { it["job_class"] == "Accounts::NoteLastSeenJob" }

  test "a GET enqueues the write without writing; the job writes the request's time" do
    travel_to(@now) do
      sign_in
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

  test "within a minute nothing more is enqueued, after it the next request enqueues again" do
    travel_to(@now) do
      sign_in
      get home_path(locale: :fr)
      assert_equal 1, last_seen_jobs

      get friends_path(locale: :fr)
      travel 59.seconds
      get home_path(locale: :fr)
      assert_equal 1, last_seen_jobs

      travel 2.seconds
      get home_path(locale: :fr)
      assert_equal 2, last_seen_jobs
    end
  end

  test "an account seen within the minute, from another browser, is not enqueued again" do
    travel_to(@now) do
      @player.update_columns(last_seen_at: @now + 10.seconds)
      sign_in
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
