require "test_helper"
require_relative "../support/steam_api_stubs"

# The import job (AD-19): one page per job, the next page enqueued after the
# commit, the app list handing over to the review pass, the run failed once
# retries are spent, and a resumed run going on from its cursor without
# duplicates.
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

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "app_list", "last_appid" => 20 } ], queue: "import") do
      Steam::ImportStepJob.perform_now(run.id, { "step" => "app_list", "last_appid" => 0 })
    end

    assert_equal 1, enqueued_jobs.size
    assert_equal 20, run.reload.last_appid
    assert_equal 2, run.apps_listed
  end

  test "the pages follow one another, the app list hands over to the review pass, and its last page completes the run" do
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: true)
    stub_app_list_page(after: 20, appids: [ 30, 40 ], more: true)
    stub_app_list_page(after: 40, appids: [ 50 ], more: false)
    calls = stub_get_items(10 => reviewed_item(10, 500), 20 => reviewed_item(20, 499), 30 => unreviewed_item(30), 40 => nil, 50 => reviewed_item(50, 80_000))

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :completed?
    assert_equal "reviews", run.step
    assert_equal 5, run.apps_listed
    assert_equal 5, run.apps_reviewed
    assert_equal 2, run.apps_kept
    assert_equal 3, run.apps_excluded
    assert_equal 50, run.last_appid
    assert_equal 1, calls.size
    assert_equal [ 10, 20, 30, 40, 50 ], Steam::App.order(:appid).pluck(:appid)
    assert_equal [ 10, 50 ], Steam::App.kept_by(run).order(:appid).pluck(:appid)
    assert_no_enqueued_jobs
  end

  test "the first reviews page is enqueued straight after the last app-list page" do
    run = start_run
    clear_enqueued_jobs
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: false)

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "reviews", "last_appid" => 0 } ], queue: "import") do
      Steam::ImportStepJob.perform_now(run.id, run.cursor)
    end

    assert_equal 1, enqueued_jobs.size
    run.reload
    assert_predicate run, :running?
    assert_equal "reviews", run.step
  end

  test "a reviews page reviews 100 apps and enqueues the next; an empty page completes the run" do
    run = start_run
    clear_enqueued_jobs
    appids = (1..150).to_a
    Steam::App.insert_all(appids.map { |appid| { appid: appid, name: "Game #{appid}", import_run_id: run.id } })
    run.update!(step: "reviews", cursor: { "step" => "reviews", "last_appid" => 0 })
    calls = stub_get_items(appids.index_with { |appid| reviewed_item(appid, appid.even? ? 600 : 10) })

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "reviews", "last_appid" => 100 } ]) do
      Steam::ImportStepJob.perform_now(run.id, run.cursor)
    end
    assert_equal (1..100).to_a, calls.last["ids"].map { |id| id["appid"] }
    assert_equal 100, run.reload.apps_reviewed

    clear_enqueued_jobs
    Steam::ImportStepJob.perform_now(run.id, run.cursor)
    assert_equal (101..150).to_a, calls.last["ids"].map { |id| id["appid"] }
    assert_equal 150, run.reload.last_appid

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id, run.reload.cursor) }
    assert_equal 2, calls.size
    run.reload
    assert_predicate run, :completed?
    assert_equal 150, run.apps_reviewed
    assert_equal 75, run.apps_kept
    assert_equal 75, run.apps_excluded
  end

  test "a stale app-list job once the run is on reviews does nothing" do
    run = start_run
    clear_enqueued_jobs
    stub_app_list_page(after: 0, appids: [ 10 ], more: false)
    Steam::ImportStepJob.perform_now(run.id, run.cursor)
    clear_enqueued_jobs
    run.reload

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id, { "step" => "app_list", "last_appid" => 0 }) }

    run.reload
    assert_equal({ "step" => "reviews", "last_appid" => 0 }, run.cursor)
    assert_predicate run, :running?
    assert_nil Steam::App.find_by!(appid: 10).reviewed_run_id
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
    stub_get_items([ 10, 20, 30, 40, 50 ].index_with { |appid| reviewed_item(appid, 1000) })
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
    assert_predicate run, :running?
    assert_equal "reviews", run.step
    assert_equal 2, run.apps_listed
    assert_equal [ 10, 20 ], Steam::App.order(:appid).pluck(:appid)
  end

  test "a job whose cursor is no longer the run's stops without calling Steam" do
    run = start_run
    clear_enqueued_jobs

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id, { "step" => "app_list", "last_appid" => 999 }) }
    assert_equal 0, run.reload.last_appid
  end

  test "a page with more results but no last_appid goes on from its highest appid" do
    run = start_run
    clear_enqueued_jobs
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=0") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [ { "appid" => 10, "name" => "A" }, { "appid" => 20, "name" => "B" } ], "have_more_results" => true } }.to_json ]
    end

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "app_list", "last_appid" => 20 } ]) do
      Steam::ImportStepJob.perform_now(run.id, run.cursor)
    end
    assert_predicate run.reload, :running?
  end

  test "a reviews page that outlasts its retries fails the run at its reviews cursor, and resuming goes on from there" do
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: false)
    steam_stubs.get(SteamApiStubs::ITEMS_PATH) { [ 503, { "Content-Type" => "application/json" }, "{}" ] }

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :failed?
    assert_equal({ "step" => "reviews", "last_appid" => 0 }, run.cursor)
    assert_includes run.latest_errors.first.message, "503"
    assert_not_includes run.latest_errors.first.message, API_KEY

    steam_stubs.clear
    stub_get_items(10 => reviewed_item(10, 800), 20 => reviewed_item(20, 12))
    perform_enqueued_jobs { Steam::ResumeImport.new.call(import_run_id: run.id) }

    run.reload
    assert_predicate run, :completed?
    assert_equal [ 10 ], Steam::App.kept_by(run).pluck(:appid)
  end
end
