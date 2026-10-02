require "test_helper"
require_relative "../support/steam_api_stubs"

# The import job (AD-19): one page per job, the next page enqueued after the
# commit, the run failed once retries are spent, and a resumed run going on
# from its cursor without duplicates.
class SteamImportStepJobTest < ActiveJob::TestCase
  include SteamApiStubs

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  def start_run
    Steam::StartImport.new.call.value!
  end

  test "it runs on the import queue" do
    assert_equal "import", Steam::ImportStepJob.new.queue_name
  end

  test "a page job imports one page and enqueues the next" do
    run = start_run
    clear_enqueued_jobs
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: true)

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "last_appid" => 20 } ], queue: "import") do
      Steam::ImportStepJob.perform_now(run.id, { "last_appid" => 0 })
    end

    assert_equal 1, enqueued_jobs.size
    assert_equal 20, run.reload.last_appid
    assert_equal 2, run.apps_listed
  end

  test "the pages follow one another until the last completes the run" do
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: true)
    stub_app_list_page(after: 20, appids: [ 30, 40 ], more: true)
    stub_app_list_page(after: 40, appids: [ 50 ], more: false)

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :completed?
    assert_equal 5, run.apps_listed
    assert_equal 50, run.last_appid
    assert_equal [ 10, 20, 30, 40, 50 ], Steam::App.order(:appid).pluck(:appid)
    assert_no_enqueued_jobs
  end

  test "a job for a run that is no longer running does nothing" do
    run = Steam::ImportRun.create!(status: :completed, step: "app_list")

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id) }
  end

  test "a job for a missing run does nothing" do
    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(-1) }
  end

  test "once the retries are spent, the run fails with the error, key redacted, at its cursor" do
    stub_app_list_page(after: 0, appids: [ 10 ], more: true)
    stub_app_list_status(503, after: 10)

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :failed?
    assert_equal 10, run.last_appid
    assert_equal 1, run.apps_listed
    message = run.latest_errors.first.message
    assert_includes message, "Steam::WebApi::Error"
    assert_includes message, "503"
    assert_not_includes message, API_KEY
    assert_equal 1, run.error_messages.size
  end

  test "a resumed run goes on from its cursor, and a page fetched twice leaves no duplicate" do
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: true)
    stub_app_list_status(500, after: 20)
    run = perform_enqueued_jobs { start_run }
    assert_predicate run.reload, :failed?

    # Resumed, the run asks again for the page after its committed cursor.
    steam_stubs.clear
    stub_app_list_page(after: 20, appids: [ 30, 40 ], more: true)
    stub_app_list_page(after: 40, appids: [ 50 ], more: false)
    perform_enqueued_jobs { Steam::ResumeImport.new.call(import_run_id: run.id) }

    run.reload
    assert_predicate run, :completed?
    assert_equal 5, run.apps_listed
    assert_equal [ 10, 20, 30, 40, 50 ], Steam::App.order(:appid).pluck(:appid)
    assert_equal Steam::App.count, Steam::App.distinct.count(:appid)
  end

  test "a job killed mid-page and run again imports the page once" do
    run = start_run
    clear_enqueued_jobs
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: false)

    # The first attempt dies between the upsert and the commit.
    Steam::ImportAppListPage.class_eval do
      alias_method :advance_without_kill, :advance
      define_method(:advance) { |*| raise Interrupt, "worker killed" }
    end
    begin
      assert_raises(Interrupt) { Steam::ImportStepJob.perform_now(run.id) }
    ensure
      Steam::ImportAppListPage.class_eval do
        alias_method :advance, :advance_without_kill
        remove_method :advance_without_kill
      end
    end
    assert_equal 0, Steam::App.count
    assert_equal 0, run.reload.last_appid

    # The queue hands the claimed job back; it runs again from the cursor.
    Steam::ImportStepJob.perform_now(run.id)

    run.reload
    assert_predicate run, :completed?
    assert_equal 2, run.apps_listed
    assert_equal [ 10, 20 ], Steam::App.order(:appid).pluck(:appid)
  end

  test "a job whose cursor is no longer the run's stops without calling Steam" do
    run = start_run
    clear_enqueued_jobs

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id, { "last_appid" => 999 }) }
    assert_equal 0, run.reload.last_appid
  end

  test "a page with more results but no last_appid goes on from its highest appid" do
    run = start_run
    clear_enqueued_jobs
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=0") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [ { "appid" => 10, "name" => "A" }, { "appid" => 20, "name" => "B" } ], "have_more_results" => true } }.to_json ]
    end

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "last_appid" => 20 } ]) do
      Steam::ImportStepJob.perform_now(run.id, run.cursor)
    end
    assert_predicate run.reload, :running?
  end
end
