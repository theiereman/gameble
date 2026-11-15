require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/rake_tasks"

# Game::ComputeDuelStatsJob runs the computation: every Monday, once a season's publication commits, and on the first deploy
# through game:compute_first_duel_stats, which leaves existing profiles alone.
class Game::ComputeDuelStatsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CatalogSeeds
  include RakeTasks

  setup { rake_task("game:compute_first_duel_stats") }

  def duel_events = Rails.configuration.event_store.read.stream(Game::DuelStatsComputed::STREAM).to_a

  test "the job queues on default and runs the computation for the reason it is given" do
    assert_equal "default", Game::ComputeDuelStatsJob.new.queue_name

    Game::ComputeDuelStatsJob.perform_now("weekly")
    Game::ComputeDuelStatsJob.perform_now("season")

    assert_equal 5, Game::DuelStat.count
    assert_equal [ { reason: "weekly" }, { reason: "season" } ], duel_events.map(&:data)
  end

  test "an unknown reason makes the job fail, and a job without a reason does not run" do
    assert_raises(Dry::Monads::UnwrapError) { Game::ComputeDuelStatsJob.perform_now("monthly") }
    assert_raises(ArgumentError) { Game::ComputeDuelStatsJob.perform_now }
    assert_equal 0, Game::DuelStat.count
  end

  test "publishing a season enqueues a season computation once the publication commits" do
    season = seed_card_seasons(distinct_scores(150))

    assert_enqueued_with(job: Game::ComputeDuelStatsJob, args: [ "season" ]) do
      Catalog::PublishSeason.new.call(number: season.number, name_en: "Spring", name_fr: "Printemps").value!
    end
  end

  test "a failed publication enqueues no computation" do
    assert_no_enqueued_jobs(only: Game::ComputeDuelStatsJob) { Catalog::PublishSeason.new.call(number: 99, name_en: "Spring", name_fr: "Printemps") }
  end

  test "the first deploy's task fills an empty table once; a second run changes nothing" do
    out, = capture_io { rake_task("game:compute_first_duel_stats").execute }
    rows = Game::DuelStat.order(:id).pluck(:id, :computed_at)

    again, = capture_io { rake_task("game:compute_first_duel_stats").execute }

    assert_equal 5, rows.size
    assert_equal rows, Game::DuelStat.order(:id).pluck(:id, :computed_at)
    assert_equal [ { reason: "first" } ], duel_events.map(&:data)
    assert_match "5 duel profile(s) computed", out
    assert_match "already exist", again
  end
end
