require "test_helper"
require_relative "../support/custom_sets"

# The daily run: one sync job per library set due, never synced first then
# least recently synced, at most the configured number a day.
class SyncSteamLibrariesJobTest < ActiveJob::TestCase
  include CustomSets

  setup { @cap = Rails.configuration.x.steam.library_daily_syncs }
  teardown { Rails.configuration.x.steam.library_daily_syncs = @cap }

  test "it runs once a day in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "SyncSteamLibrariesJob", "queue" => "default", "schedule" => "every day at 5am" },
        recurring.dig(env, "sync_steam_libraries"), env)
    end
  end

  test "it enqueues up to the cap, the set never synced first, then the oldest sync, and none of a banned player" do
    player, moderator, administrator = accounts_players(:player, :moderator, :administrator)
    create_library_set(player, synced_at: 1.hour.ago)
    never = create_library_set(moderator, synced_at: nil)
    oldest = create_library_set(administrator, synced_at: 3.days.ago)
    create_library_set(accounts_players(:banned), synced_at: nil)
    Rails.configuration.x.steam.library_daily_syncs = 2

    SyncSteamLibrariesJob.perform_now

    assert_equal [ [ moderator.id, never.token ], [ administrator.id, oldest.token ] ], enqueued_jobs.map { it.fetch("arguments") }
    assert_equal [ "steam_library" ] * 2, enqueued_jobs.map { it.fetch("queue_name") }
    assert_equal [ "SyncSteamLibraryJob" ] * 2, enqueued_jobs.map { it.fetch("job_class") }
  end

  test "no library set, no job" do
    assert_no_enqueued_jobs { SyncSteamLibrariesJob.perform_now }
  end
end
