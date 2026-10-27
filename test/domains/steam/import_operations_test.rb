require "test_helper"
require_relative "../../support/steam_api_stubs"
require_relative "../../support/catalog_seeds"

# The operations of an import run: each one's success and every
# failure, and the event each publishes.
class Steam::ImportOperationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SteamApiStubs
  include CatalogSeeds

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def running_run(last_appid: 0, apps_listed: 0)
    Steam::ImportRun.create!(status: :running, step: "app_list", cursor: { "step" => "app_list", "last_appid" => last_appid }, counts: { "apps_listed" => apps_listed }, started_at: 1.minute.ago)
  end

  def failed_run(last_appid: 0)
    Steam::ImportRun.create!(status: :failed, step: "app_list", cursor: { "step" => "app_list", "last_appid" => last_appid }, counts: { "apps_listed" => 0 }, started_at: 1.hour.ago, finished_at: 1.minute.ago,
      error_messages: [ { "at" => 1.minute.ago.utc.iso8601, "message" => "Steam::WebApi::Error: boom" } ])
  end

  # StartImport

  test "starting an import opens a running run on the app list and enqueues its first page on the import queue" do
    result = nil
    assert_enqueued_with(job: Steam::ImportStepJob, queue: "import") { result = Steam::StartImport.new.call }

    assert result.success?
    run = result.value!.reload
    assert_predicate run, :running?
    assert_equal "app_list", run.step
    assert_equal 0, run.last_appid
    assert_equal 0, run.apps_listed
    assert_predicate run.started_at, :present?
    assert_predicate run.token, :present?
    assert_equal({ "step" => "app_list", "last_appid" => 0 }, run.cursor)
    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "app_list", "last_appid" => 0 } ])

    events = events_of(run)
    assert_equal [ Steam::ImportRunStarted ], events.map(&:class)
    assert_equal({ import_run_id: run.id }, events.first.data)
  end

  [ :pending, :running ].each do |status|
    test "starting an import while one is #{status} fails with run_in_progress" do
      Steam::ImportRun.create!(status: status, step: "app_list")

      result = nil
      assert_no_enqueued_jobs { result = Steam::StartImport.new.call }

      assert_equal :run_in_progress, result.failure
      assert_equal 1, Steam::ImportRun.count
    end
  end

  test "a run started by someone else after the check meets the one-active-run index" do
    Steam::ImportRun.create!(status: :running, step: "app_list")
    operation = Steam::StartImport.new
    operation.define_singleton_method(:refuse_active_run) { Success() }

    result = operation.call

    assert_equal :run_in_progress, result.failure
    assert_equal 1, Steam::ImportRun.count
    assert_empty Rails.configuration.event_store.read.of_type(Steam::ImportRunStarted).to_a
  end

  test "the database refuses a second active run" do
    Steam::ImportRun.create!(status: :pending)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Steam::ImportRun.transaction(requires_new: true) { Steam::ImportRun.create!(status: :running) }
    end
  end

  test "starting an import after finished runs succeeds" do
    Steam::ImportRun.create!(status: :completed, step: "app_list")
    failed_run

    assert Steam::StartImport.new.call.success?
  end

  # ImportAppListPage

  test "a page upserts its apps, moves the cursor and the count, and keeps the run going" do
    run = running_run(last_appid: 100, apps_listed: 5)
    stub_app_list_page(after: 100, appids: [ 101, 105 ], more: true)

    result = Steam::ImportAppListPage.new.call(import_run_id: run.id)

    assert result.success?
    run.reload
    assert_predicate run, :running?
    assert_equal 105, run.last_appid
    assert_equal 7, run.apps_listed
    app = Steam::App.find_by!(appid: 105)
    assert_equal "Game 105", app.name
    assert_equal Time.at(1_700_000_105).utc, app.last_modified
    assert_equal 1050, app.price_change_number
    assert_equal run, app.import_run

    events = events_of(run)
    assert_equal [ Steam::AppListPageImported ], events.map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 105 }, events.first.data)
  end

  test "an app already known is updated, not duplicated" do
    previous = Steam::ImportRun.create!(status: :completed, step: "app_list")
    Steam::App.create!(appid: 101, name: "Old name", import_run: previous)
    run = running_run(last_appid: 100)
    stub_app_list_page(after: 100, appids: [ 101 ], more: true)

    Steam::ImportAppListPage.new.call(import_run_id: run.id)

    assert_equal 1, Steam::App.where(appid: 101).count
    app = Steam::App.find_by!(appid: 101)
    assert_equal "Game 101", app.name
    assert_equal run, app.import_run
  end

  test "the last page hands the run over to the review pass, its cursor at the start" do
    run = running_run(last_appid: 200)
    stub_app_list_page(after: 200, appids: [ 201, 202 ], more: false)

    result = Steam::ImportAppListPage.new.call(import_run_id: run.id)

    assert result.success?
    run.reload
    assert_predicate run, :running?
    assert_nil run.finished_at
    assert_equal "reviews", run.step
    assert_equal({ "step" => "reviews", "last_appid" => 0 }, run.cursor)
    assert_equal 2, run.apps_listed
    assert_equal [ Steam::AppListPageImported, Steam::ImportStepFinished ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 202 }, events_of(run).first.data)
    assert_equal({ import_run_id: run.id, step: "app_list" }, events_of(run).last.data)
  end

  test "an empty last page hands over to the review pass" do
    run = running_run(last_appid: 300, apps_listed: 3)
    stub_app_list_page(after: 300, appids: [], more: false)

    Steam::ImportAppListPage.new.call(import_run_id: run.id)

    run.reload
    assert_predicate run, :running?
    assert_equal "reviews", run.step
    assert_equal 0, run.last_appid
    assert_equal 3, run.apps_listed
  end

  test "a page that does not move the cursor ends the step instead of looping" do
    run = running_run(last_appid: 400)
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=400") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [], "have_more_results" => true, "last_appid" => 400 } }.to_json ]
    end

    Steam::ImportAppListPage.new.call(import_run_id: run.id)

    assert_equal "reviews", run.reload.step
  end

  test "an appid repeated in a page is kept once, its first entry, and named in the run's errors" do
    run = running_run(last_appid: 0, apps_listed: 1)
    apps = [ { "appid" => 10, "name" => "Ten" }, { "appid" => 20, "name" => "First" }, { "appid" => 20, "name" => "Second" }, { "appid" => 20, "name" => "Third" } ]
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=0") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => apps, "have_more_results" => true, "last_appid" => 20 } }.to_json ]
    end

    assert Steam::ImportAppListPage.new.call(import_run_id: run.id).success?

    assert_equal [ [ 10, "Ten" ], [ 20, "First" ] ], Steam::App.order(:appid).pluck(:appid, :name)
    run.reload
    assert_equal [ 3, 20 ], [ run.apps_listed, run.last_appid ]
    assert_equal [ "appid 20: repeated_in_page" ], run.latest_errors.map(&:message)
    assert_predicate run, :running?
  end

  test "the malformed entries of a page are skipped and counted in one error line" do
    run = running_run(last_appid: 5)
    apps = [ {}, { "appid" => "x" }, { "appid" => -3 }, "junk", { "appid" => 2**40 }, { "appid" => 10, "name" => "Ten" } ]
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=5") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => apps, "have_more_results" => true, "last_appid" => 10 } }.to_json ]
    end

    assert Steam::ImportAppListPage.new.call(import_run_id: run.id).success?

    assert_equal [ 10 ], Steam::App.pluck(:appid)
    run.reload
    assert_equal [ 1, 10 ], [ run.apps_listed, run.last_appid ]
    assert_equal [ "app list after appid 5: 5 malformed_entries" ], run.latest_errors.map(&:message)
  end

  test "a page for an unknown run fails with not_found" do
    assert_equal :not_found, Steam::ImportAppListPage.new.call(import_run_id: -1).failure
  end

  [ :completed, :failed, :pending ].each do |status|
    test "a page for a #{status} run fails with not_running and calls nothing" do
      run = Steam::ImportRun.create!(status: status, step: "app_list")

      assert_equal :not_running, Steam::ImportAppListPage.new.call(import_run_id: run.id).failure
      assert_equal 0, Steam::App.count
    end
  end

  test "a page whose cursor moved meanwhile fails with cursor_moved and writes nothing" do
    run = running_run(last_appid: 500)
    stub_app_list_page(after: 500, appids: [ 501 ], more: true)
    client = Steam::WebApi.new
    client.define_singleton_method(:get_app_list) do |**args|
      page = super(**args)
      Steam::ImportRun.where(id: run.id).update_all(cursor: { "last_appid" => 501 })
      page
    end

    result = Steam::ImportAppListPage.new(client: client).call(import_run_id: run.id)

    assert_equal :cursor_moved, result.failure
    assert_equal 0, Steam::App.count
    assert_empty events_of(run)
  end

  test "a page interrupted before its commit leaves no app and the cursor where it was" do
    run = running_run(last_appid: 600)
    stub_app_list_page(after: 600, appids: [ 601, 602 ], more: true)
    operation = Steam::ImportAppListPage.new
    operation.define_singleton_method(:advance) { |*| raise Interrupt, "worker killed" }

    assert_raises(Interrupt) { operation.call(import_run_id: run.id) }

    assert_equal 600, run.reload.last_appid
    assert_equal 0, Steam::App.count
    assert_empty events_of(run)
  end

  test "a Steam error raises with the key redacted and leaves the run as it was" do
    run = running_run(last_appid: 700)
    stub_app_list_status(500)

    error = assert_raises(Steam::WebApi::Error) { Steam::ImportAppListPage.new.call(import_run_id: run.id) }

    assert_not_includes error.message, API_KEY
    assert_predicate run.reload, :running?
    assert_equal 700, run.last_appid
  end

  # FailImport

  test "failing a running run appends the error and stops it at its cursor" do
    run = running_run(last_appid: 800)

    result = Steam::FailImport.new.call(import_run_id: run.id, error: "Steam::WebApi::Error: 503")

    assert result.success?
    run.reload
    assert_predicate run, :failed?
    assert_predicate run.finished_at, :present?
    assert_equal 800, run.last_appid
    assert_equal [ "Steam::WebApi::Error: 503" ], run.latest_errors.map(&:message)
    assert_equal({ import_run_id: run.id, status: "failed" }, events_of(run).last.data)
    assert_instance_of Steam::ImportRunFinished, events_of(run).last
  end

  test "a run keeps only its latest errors" do
    run = running_run
    run.update!(error_messages: Array.new(Steam::ImportRun::ERROR_LIMIT) { |i| { "at" => Time.current.utc.iso8601, "message" => "old #{i}" } })

    Steam::FailImport.new.call(import_run_id: run.id, error: "new")

    assert_equal Steam::ImportRun::ERROR_LIMIT, run.reload.error_messages.size
    assert_equal "new", run.latest_errors.first.message
  end

  test "failing an unknown run fails with not_found" do
    assert_equal :not_found, Steam::FailImport.new.call(import_run_id: -1, error: "x").failure
  end

  test "failing a run that is not running fails with not_running" do
    run = failed_run

    assert_equal :not_running, Steam::FailImport.new.call(import_run_id: run.id, error: "x").failure
    assert_equal 1, run.reload.error_messages.size
  end

  # CompleteImport

  test "completing a run that is not running fails with not_running" do
    run = failed_run

    assert_equal :not_running, Steam::CompleteImport.new.call(import_run: run).failure
    assert_predicate run.reload, :failed?
  end

  # ResumeImport

  test "resuming a failed run runs it again from its cursor and enqueues its next page" do
    run = failed_run(last_appid: 900)

    result = nil
    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "app_list", "last_appid" => 900 } ], queue: "import") { result = Steam::ResumeImport.new.call(import_run_id: run.id) }

    assert result.success?
    run.reload
    assert_predicate run, :running?
    assert_nil run.finished_at
    assert_equal 900, run.last_appid
    assert_equal 1, run.error_messages.size
    assert_equal [ Steam::ImportRunStarted ], events_of(run).map(&:class)
  end

  test "resuming an unknown run fails with not_found" do
    assert_equal :not_found, Steam::ResumeImport.new.call(import_run_id: -1).failure
  end

  [ :running, :completed, :pending ].each do |status|
    test "resuming a #{status} run fails with not_resumable" do
      run = Steam::ImportRun.create!(status: status, step: "app_list")

      assert_no_enqueued_jobs do
        assert_equal :not_resumable, Steam::ResumeImport.new.call(import_run_id: run.id).failure
      end
    end
  end

  test "resuming while another run is active fails with run_in_progress" do
    run = failed_run
    running_run

    assert_equal :run_in_progress, Steam::ResumeImport.new.call(import_run_id: run.id).failure
    assert_predicate run.reload, :failed?
  end

  test "resuming a failed run that is not the latest fails with not_latest" do
    older = failed_run
    older.update!(created_at: 2.days.ago)
    Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

    assert_no_enqueued_jobs do
      assert_equal :not_latest, Steam::ResumeImport.new.call(import_run_id: older.id).failure
    end
    assert_predicate older.reload, :failed?
    assert_empty events_of(older)
  end

  test "resuming an older failed run while the latest is running fails with run_in_progress" do
    older = failed_run
    older.update!(created_at: 2.days.ago)
    running_run

    assert_equal :run_in_progress, Steam::ResumeImport.new.call(import_run_id: older.id).failure
  end

  test "ResumeImport.refusal says why a run cannot be resumed, leaving out the active-run check" do
    older = failed_run
    older.update!(created_at: 2.days.ago)
    assert_nil Steam::ResumeImport.refusal(older)

    latest = Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)
    assert_equal :not_latest, Steam::ResumeImport.refusal(older)
    assert_equal :not_resumable, Steam::ResumeImport.refusal(latest)

    latest.update!(status: :running, finished_at: nil)
    assert_equal :not_resumable, Steam::ResumeImport.refusal(latest)
    assert_equal :not_latest, Steam::ResumeImport.refusal(older)
  end

  # AbandonImport

  def abandon(run)
    Steam::AbandonImport.new.call(import_run_id: run.id)
  end

  test "abandoning the latest failed run keeps its finish and errors, publishes its event, and lets a new run start" do
    run = failed_run(last_appid: 900)
    finished_at = run.finished_at

    result = abandon(run)

    assert_equal run.id, result.value!.id
    run.reload
    assert_predicate run, :abandoned?
    assert_equal [ finished_at.to_i, 1, 900 ], [ run.finished_at.to_i, run.error_messages.size, run.last_appid ]
    assert_equal [ Steam::ImportRunAbandoned ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id }, events_of(run).first.data)
    assert_nil Steam::UnfinishedImportRun.call
    assert_equal :not_resumable, Steam::ResumeImport.new.call(import_run_id: run.id).failure
    assert_equal :not_completed, Steam::RescoreCards.new.call(import_run_id: run.id).failure
    assert Steam::StartImport.new.call.success?
  end

  test "a run on the cards step that wrote nothing in its pass can be abandoned" do
    run = failed_run
    run.update!(step: "cards", cursor: { "step" => "cards", "last_appid" => 0 })

    assert abandon(run).success?
    assert_predicate run.reload, :abandoned?
  end

  test "a run on the cards step past appid 0 whose every card was refused can be abandoned" do
    run = failed_run
    run.update!(step: "cards", cursor: { "step" => "cards", "last_appid" => 40 }, counts: { "cards_written" => 0, "cards_refused" => 3 })

    assert abandon(run).success?
    assert_predicate run.reload, :abandoned?
  end

  test "a run that staged cards in its pass can be abandoned: its staged cards go and the draft is left alone" do
    run = failed_run
    run.update!(step: "cards", cursor: { "step" => "cards", "last_appid" => 40 }, counts: { "cards_written" => 2 })
    draft = seed_card_seasons([ 0.5, 0.6 ])
    card = Catalog::Card.first
    Catalog::StageCardSeason.new.call(batch_token: run.token, card_id: card.id, prestige_score: 0.9, prestige_score_version: 1, rating: 90.0)

    assert abandon(run).success?
    assert_predicate run.reload, :abandoned?
    assert_empty Catalog::StagedCardSeason.where(batch_token: run.token)
    assert_equal 2, Catalog::CardSeason.where(season: draft).count
  end

  [ :running, :completed, :pending, :abandoned ].each do |status|
    test "abandoning a #{status} run fails with not_abandonable" do
      run = Steam::ImportRun.create!(status: status, step: "app_list")

      assert_equal :not_abandonable, abandon(run).failure
      assert_equal status.to_s, run.reload.status
      assert_empty events_of(run)
    end
  end

  test "abandoning a failed run that is not the latest fails with not_latest" do
    older = failed_run
    older.update!(created_at: 2.days.ago)
    Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

    assert_equal :not_latest, abandon(older).failure
    assert_predicate older.reload, :failed?
  end

  test "abandoning an unknown run fails with not_found" do
    assert_equal :not_found, Steam::AbandonImport.new.call(import_run_id: -1).failure
  end

  test "AbandonImport.refusal says why a run cannot be abandoned" do
    run = failed_run
    assert_nil Steam::AbandonImport.refusal(run)

    run.update!(step: "cards", cursor: { "step" => "cards", "last_appid" => 1 }, counts: { "cards_written" => 1 })
    assert_nil Steam::AbandonImport.refusal(run)

    latest = Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)
    assert_equal :not_latest, Steam::AbandonImport.refusal(run)
    assert_equal :not_abandonable, Steam::AbandonImport.refusal(latest)
  end

  # UnfinishedImportRun

  test "the unfinished run is the latest one unless it completed, was promoted or was abandoned" do
    assert_nil Steam::UnfinishedImportRun.call

    run = failed_run
    assert_equal run, Steam::UnfinishedImportRun.call

    %w[running pending ready].each do |status|
      run.update_columns(status:)
      assert_equal run, Steam::UnfinishedImportRun.call, status
    end
    %w[completed promoted abandoned].each do |status|
      run.update_columns(status:)
      assert_nil Steam::UnfinishedImportRun.call, status
    end
  end

  test "an abandoned latest run is skipped: a run before it that failed after staging cards is still unfinished" do
    Steam::ImportRun.create!(status: :completed, step: "cards", created_at: 3.days.ago, finished_at: 3.days.ago)
    partial = Steam::ImportRun.create!(status: :failed, step: "cards", cursor: { "step" => "cards", "last_appid" => 40 },
      counts: { "cards_written" => 2 }, created_at: 2.days.ago, finished_at: 2.days.ago)
    abandoned = failed_run
    abandon(abandoned)

    assert_predicate abandoned.reload, :abandoned?
    assert_equal partial, Steam::UnfinishedImportRun.call

    partial.update_columns(status: "completed")
    assert_nil Steam::UnfinishedImportRun.call
  end

  test "once the latest run is abandoned, a failed run before it that wrote no card can be abandoned and stops blocking" do
    older = failed_run
    older.update!(created_at: 2.days.ago)
    newer = failed_run
    assert_equal :not_latest, Steam::AbandonImport.refusal(older)

    assert abandon(newer).success?
    assert_equal older, Steam::UnfinishedImportRun.call
    assert_nil Steam::AbandonImport.refusal(older)

    assert abandon(older).success?
    assert_predicate older.reload, :abandoned?
    assert_nil Steam::UnfinishedImportRun.call
  end

  test "once the latest run is abandoned, a run before it that staged cards in its pass can be abandoned too" do
    partial = Steam::ImportRun.create!(status: :failed, step: "cards", cursor: { "step" => "cards", "last_appid" => 40 },
      counts: { "cards_written" => 2 }, created_at: 2.days.ago, finished_at: 2.days.ago)
    abandon(failed_run)

    assert_equal partial, Steam::UnfinishedImportRun.call
    assert abandon(partial).success?
    assert_nil Steam::UnfinishedImportRun.call
  end

  test "the database accepts every run status and refuses an unknown one" do
    run = Steam::ImportRun.create!(status: :completed, step: "app_list")

    Steam::ImportRun.statuses.each_value do |status|
      assert_equal 1, Steam::ImportRun.where(id: run.id).update_all(status:), status
    end
    assert_raises(ActiveRecord::StatementInvalid) { Steam::ImportRun.where(id: run.id).update_all(status: "lost") }
  end

  test "every failure code has a message in both locales" do
    codes = {
      Steam::StartImport => %i[run_in_progress run_awaiting_promotion],
      Steam::ImportAppListPage => %i[not_found not_running cursor_moved],
      Steam::ImportReviewsPage => %i[not_found not_running cursor_moved],
      Steam::ImportTagsPage => %i[not_found not_running cursor_moved],
      Steam::ImportDetailsPage => %i[not_found not_running cursor_moved],
      Steam::ImportCardsPage => %i[not_found not_running cursor_moved],
      Steam::FinishImportStep => %i[not_running],
      Steam::CompleteImport => %i[not_running],
      Steam::FailImport => %i[not_found not_running],
      Steam::ResumeImport => %i[not_found not_resumable run_in_progress not_latest],
      Steam::AbandonImport => %i[not_found not_abandonable not_latest],
      Steam::PromoteImport => %i[not_found not_ready empty_batch stale_batch],
      Steam::DiscardImport => %i[not_found not_ready],
      Steam::RescoreCards => %i[not_found not_latest not_completed already_published run_in_progress run_awaiting_promotion]
    }
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        codes.each do |operation, failures|
          failures.each { |code| assert_predicate operation.failure_message(code), :present?, "#{operation} #{code} #{locale}" }
        end
      end
    end
  end
end
