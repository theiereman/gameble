require "test_helper"
require_relative "../support/steam_api_stubs"

# A worker killed outright loses its page job (AD-19): the recurring recovery
# puts a stalled run back on the import queue, and the run goes on from its
# cursor without counting a page twice.
class SteamRecoverStalledImportsJobTest < ActiveJob::TestCase
  include SteamApiStubs

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  def stalled_run(last_appid: 20, apps_listed: 2)
    Steam::ImportRun.create!(status: :running, step: "app_list", started_at: 1.hour.ago,
      cursor: { "step" => "app_list", "last_appid" => last_appid }, counts: { "apps_listed" => apps_listed }).tap do |run|
      run.update_columns(updated_at: (Steam::StalledImportRuns::STALL_AFTER + 1.minute).ago)
    end
  end

  test "it is scheduled in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal "Steam::RecoverStalledImportsJob", recurring.dig(env, "recover_stalled_imports", "class"), env
    end
  end

  test "a stalled run gets its page job back; a moving or finished run does not" do
    stalled = stalled_run
    Steam::ImportRun.create!(status: :completed, step: "app_list", updated_at: 1.hour.ago)

    assert_enqueued_jobs 1, only: Steam::ImportStepJob do
      Steam::RecoverStalledImportsJob.perform_now
    end
    assert_enqueued_with(job: Steam::ImportStepJob, args: [ stalled.id, { "step" => "app_list", "last_appid" => 20 } ], queue: "import")

    clear_enqueued_jobs
    stalled.touch
    assert_no_enqueued_jobs(only: Steam::ImportStepJob) { Steam::RecoverStalledImportsJob.perform_now }
  end

  test "the recovered run goes on from its cursor without duplicates" do
    run = stalled_run
    Steam::App.insert_all([ 10, 20 ].map { |appid| { appid: appid, name: "Game #{appid}", import_run_id: run.id } })
    stub_app_list_page(after: 20, appids: [ 30 ], more: false)
    stub_get_items([ 10, 20, 30 ].index_with { |appid| reviewed_item(appid, 1000) })

    perform_enqueued_jobs { Steam::RecoverStalledImportsJob.perform_now }

    run.reload
    assert_predicate run, :completed?
    assert_equal 3, run.apps_listed
    assert_equal 3, run.apps_kept
    assert_equal [ 10, 20, 30 ], Steam::App.order(:appid).pluck(:appid)
  end

  test "a lost job that turns up after the recovery imported its page stops" do
    run = stalled_run
    stub_app_list_page(after: 20, appids: [ 30 ], more: true)
    stub_app_list_page(after: 30, appids: [ 40 ], more: false)
    stub_get_items(30 => reviewed_item(30, 1000), 40 => reviewed_item(40, 1000))
    lost_cursor = run.cursor

    perform_enqueued_jobs { Steam::RecoverStalledImportsJob.perform_now }
    assert_predicate run.reload, :completed?

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id, lost_cursor) }
    assert_equal 2 + 2, run.reload.apps_listed
  end

  test "recoveries piled up while the worker was down make one chain of page jobs" do
    run = stalled_run
    stub_app_list_page(after: 20, appids: [ 30 ], more: true)
    stub_app_list_page(after: 30, appids: [ 40 ], more: false)
    3.times { Steam::RecoverStalledImportsJob.perform_now }
    assert_enqueued_jobs 3, only: Steam::ImportStepJob

    # The three jobs carry the same cursor: the first imports the page and
    # enqueues the next, the two others stop.
    perform_enqueued_jobs(only: Steam::ImportStepJob)
    assert_enqueued_jobs 1, only: Steam::ImportStepJob
    assert_equal 30, run.reload.last_appid

    perform_enqueued_jobs(only: Steam::ImportStepJob)

    # The last app-list page hands over to the review pass.
    run.reload
    assert_predicate run, :running?
    assert_equal "reviews", run.step
    assert_equal 2 + 2, run.apps_listed
    assert_enqueued_jobs 1, only: Steam::ImportStepJob
  end
end
