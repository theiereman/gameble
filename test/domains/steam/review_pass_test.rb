require "test_helper"
require_relative "../../support/steam_api_stubs"

# The review pass of an import run (epic 2, R3, R5): Steam::FinishImportStep,
# Steam::ImportReviewsPage, the review floor and the apps kept by a run.
class Steam::ReviewPassTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SteamApiStubs

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def reviews_run(last_appid: 0, counts: {})
    Steam::ImportRun.create!(status: :running, step: "reviews", cursor: { "step" => "reviews", "last_appid" => last_appid },
      counts: { "apps_listed" => 0 }.merge(counts), started_at: 1.minute.ago)
  end

  def list(run, *appids)
    Steam::App.insert_all(appids.map { |appid| { appid: appid, name: "Game #{appid}", import_run_id: run.id } })
  end

  def review_page(run)
    Steam::ImportReviewsPage.new.call(import_run_id: run.id, cursor: run.cursor)
  end

  # FinishImportStep

  test "finishing the app list moves the same run to the review pass, its cursor at the start" do
    run = Steam::ImportRun.create!(status: :running, step: "app_list", cursor: { "step" => "app_list", "last_appid" => 900 })

    result = Steam::FinishImportStep.new.call(import_run: run)

    assert_same run, result.value!
    run.reload
    assert_predicate run, :running?
    assert_equal "reviews", run.step
    assert_equal({ "step" => "reviews", "last_appid" => 0 }, run.cursor)
    assert_equal [ Steam::ImportStepFinished ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, step: "app_list" }, events_of(run).first.data)
  end

  test "finishing the review pass moves the run to the tags" do
    run = reviews_run(last_appid: 70)

    Steam::FinishImportStep.new.call(import_run: run)

    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "tags", "last_appid" => 0 }, run.cursor)
    assert_equal "tags", run.step
  end

  test "finishing the last step readies the run for promotion" do
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 70 }, started_at: 1.minute.ago)

    result = Steam::FinishImportStep.new.call(import_run: run)

    assert_same run, result.value!
    run.reload
    assert_predicate run, :ready?
    assert_predicate run.finished_at, :present?
    assert_equal "cards", run.step
    assert_equal [ Steam::ImportStepFinished, Steam::ImportRunFinished ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, step: "cards" }, events_of(run).first.data)
    assert_equal({ import_run_id: run.id, status: "ready" }, events_of(run).last.data)
  end

  test "finishing a step of a run that is not running fails with not_running" do
    run = Steam::ImportRun.create!(status: :failed, step: "app_list")

    assert_equal :not_running, Steam::FinishImportStep.new.call(import_run: run).failure
    assert_equal "app_list", run.reload.step
    assert_empty events_of(run)
  end

  # ImportReviewsPage

  test "a page stores the review summaries and verdicts, moves the cursor and the counts" do
    run = reviews_run(counts: { "apps_reviewed" => 10, "apps_kept" => 4, "apps_excluded" => 6 })
    list(run, 10, 20, 30, 40, 50, 60)
    calls = stub_get_items(10 => reviewed_item(10, 812, percent: 93), 20 => reviewed_item(20, 500), 30 => reviewed_item(30, 499),
      40 => unreviewed_item(40), 50 => unavailable_item(50), 60 => nil)
    page = Steam::ImportReviewsPage.new(page_size: 6)

    result = page.call(import_run_id: run.id, cursor: run.cursor)

    assert result.success?
    assert_equal 1, calls.size
    assert_equal({ "ids" => [ 10, 20, 30, 40, 50, 60 ].map { |appid| { "appid" => appid } },
      "context" => { "language" => "english", "country_code" => "US" }, "data_request" => { "include_reviews" => true } }, calls.first)

    apps = Steam::App.order(:appid).index_by(&:appid)
    assert_equal [ 812, 93, nil ], apps[10].slice(:review_count, :review_percent_positive, :review_exclusion).values
    assert_equal reviewed_item(10, 812, percent: 93)["reviews"], apps[10].reviews
    assert_equal [ 500, nil ], apps[20].slice(:review_count, :review_exclusion).values, "exactly 500 is kept"
    assert_equal [ 499, "too_few_reviews" ], apps[30].slice(:review_count, :review_exclusion).values
    assert_equal [ 0, "too_few_reviews" ], apps[40].slice(:review_count, :review_exclusion).values, "no summary counts 0"
    assert_equal [ nil, "unavailable" ], apps[50].slice(:review_count, :review_exclusion).values, "success other than 1"
    assert_equal [ nil, "unavailable" ], apps[60].slice(:review_count, :review_exclusion).values, "absent from the answer"
    assert(apps.values.all? { |app| app.reviewed_run_id == run.id && app.import_run_id == run.id && app.name == "Game #{app.appid}" })
    assert_equal [ 10, 20 ], Steam::App.kept_by(run).order(:appid).pluck(:appid)

    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "reviews", "last_appid" => 60 }, run.cursor)
    assert_equal [ 16, 6, 10 ], [ run.apps_reviewed, run.apps_kept, run.apps_excluded ]
    assert_equal [ Steam::ReviewsPageImported ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 60 }, events_of(run).first.data)
  end

  test "an appid Steam does not know is answered id 0, success 15, and is unavailable" do
    run = reviews_run
    list(run, 10, 20)
    stub_get_items(10 => reviewed_item(10, 900))

    review_page(run)

    assert_equal "unavailable", Steam::App.find_by!(appid: 20).review_exclusion
    assert_nil Steam::App.find_by!(appid: 10).review_exclusion
  end

  test "a page takes the next 100 apps of this run after the cursor, in appid order" do
    run = reviews_run(last_appid: 5)
    list(run, *(1..120).to_a.reverse)
    calls = stub_get_items((1..120).index_with { |appid| reviewed_item(appid, 1) })

    review_page(run)

    assert_equal [ (6..105).to_a ], calls.map { |input| input["ids"].map { |id| id["appid"] } }
    assert_equal (6..105).to_a, Steam::App.where(reviewed_run_id: run.id).order(:appid).pluck(:appid)
    assert_equal 105, run.reload.last_appid
    assert_equal 100, run.apps_reviewed
  end

  test "an app not relisted by this run is neither paged nor kept by it" do
    earlier = Steam::ImportRun.create!(status: :completed, step: "reviews")
    run = reviews_run
    list(earlier, 10)
    list(run, 20)
    calls = stub_get_items(10 => reviewed_item(10, 5000), 20 => reviewed_item(20, 5000))

    review_page(run)
    review_page(run.reload)

    assert_equal [ [ 20 ] ], calls.map { |input| input["ids"].map { |id| id["appid"] } }
    assert_equal [ 20 ], Steam::App.kept_by(run).pluck(:appid)
    assert_nil Steam::App.find_by!(appid: 10).reviewed_run_id
    assert_equal "tags", run.reload.step
  end

  test "an app excluded by an earlier run that now has 600 reviews is kept by the new run" do
    earlier = Steam::ImportRun.create!(status: :completed, step: "reviews")
    list(earlier, 10)
    Steam::App.where(appid: 10).update_all(review_count: 120, reviewed_run_id: earlier.id, review_exclusion: "too_few_reviews")
    run = reviews_run
    Steam::App.where(appid: 10).update_all(import_run_id: run.id)
    stub_get_items(10 => reviewed_item(10, 600))

    review_page(run)

    app = Steam::App.find_by!(appid: 10)
    assert_equal [ 600, run.id, nil ], [ app.review_count, app.reviewed_run_id, app.review_exclusion ]
    assert_equal [ 10 ], Steam::App.kept_by(run).pluck(:appid)
    assert_empty Steam::App.kept_by(earlier)
  end

  test "with no app of this run after the cursor, the step finishes without calling Steam and the run moves to the tags" do
    run = reviews_run(last_appid: 20)
    list(run, 10, 20)
    calls = stub_get_items({})

    result = review_page(run)

    assert result.success?
    assert_empty calls
    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "tags", "last_appid" => 0 }, run.cursor)
    assert_equal [ Steam::ImportStepFinished ], events_of(run).map(&:class)
  end

  test "a page of an app-list cursor once the run is on reviews fails with cursor_moved and calls nothing" do
    run = reviews_run
    list(run, 10)
    calls = stub_get_items(10 => reviewed_item(10, 900))

    result = Steam::ImportReviewsPage.new.call(import_run_id: run.id, cursor: { "step" => "app_list", "last_appid" => 0 })

    assert_equal :cursor_moved, result.failure
    assert_empty calls
    assert_nil Steam::App.find_by!(appid: 10).reviewed_run_id
  end

  test "a page whose cursor moved meanwhile fails with cursor_moved and writes nothing" do
    run = reviews_run
    list(run, 10)
    stub_get_items(10 => reviewed_item(10, 900))
    client = Steam::WebApi.new
    client.define_singleton_method(:get_items) do |**args|
      items = super(**args)
      Steam::ImportRun.where(id: run.id).update_all(cursor: { "step" => "reviews", "last_appid" => 10 })
      items
    end

    result = Steam::ImportReviewsPage.new(client: client).call(import_run_id: run.id)

    assert_equal :cursor_moved, result.failure
    assert_nil Steam::App.find_by!(appid: 10).reviewed_run_id
    assert_empty events_of(run)
  end

  test "a page for an unknown run fails with not_found" do
    assert_equal :not_found, Steam::ImportReviewsPage.new.call(import_run_id: -1).failure
  end

  test "a page for a run on the app list fails with not_running" do
    run = Steam::ImportRun.create!(status: :running, step: "app_list", cursor: { "step" => "app_list", "last_appid" => 0 })

    assert_equal :not_running, Steam::ImportReviewsPage.new.call(import_run_id: run.id).failure
  end

  [ :completed, :failed, :pending ].each do |status|
    test "a page for a #{status} run fails with not_running" do
      run = Steam::ImportRun.create!(status: status, step: "reviews")

      assert_equal :not_running, Steam::ImportReviewsPage.new.call(import_run_id: run.id).failure
    end
  end

  test "a Steam error raises with the key redacted and leaves the run and its apps as they were" do
    run = reviews_run
    list(run, 10)
    steam_stubs.get(ITEMS_PATH) { [ 503, {}, "" ] }

    error = assert_raises(Steam::WebApi::Error) { review_page(run) }

    assert_not_includes error.message, API_KEY
    run.reload
    assert_predicate run, :running?
    assert_equal 0, run.last_appid
    assert_nil Steam::App.find_by!(appid: 10).reviewed_run_id
  end

  test "a page never creates an app" do
    run = reviews_run
    list(run, 10)
    stub_get_items(10 => reviewed_item(10, 900), 11 => reviewed_item(11, 900))

    assert_no_difference(-> { Steam::App.count }) { review_page(run) }
  end

  # ReviewPolicy

  test "the review floor is 500" do
    assert_equal 500, Steam::ReviewPolicy::MIN_REVIEWS
    assert_predicate Steam::ReviewPolicy.verdict(reviewed_item(1, 500)), :kept?
    assert_equal "too_few_reviews", Steam::ReviewPolicy.verdict(reviewed_item(1, 499)).exclusion
    assert_equal "unavailable", Steam::ReviewPolicy.verdict(nil).exclusion
  end

  def summary_item(appid, summary)
    { "item_type" => 0, "id" => appid, "success" => 1, "appid" => appid, "reviews" => { "summary_filtered" => summary } }
  end

  test "malformed review values never raise: the app is excluded malformed_reviews and the invalid values are stored as NULL" do
    run = reviews_run
    list(run, *(1..10).to_a)
    stub_get_items(
      1 => summary_item(1, "review_count" => 900, "percent_positive" => 150),
      2 => summary_item(2, "review_count" => 900, "percent_positive" => -1),
      3 => summary_item(3, "review_count" => 900, "percent_positive" => "abc"),
      4 => summary_item(4, "review_count" => 900),
      5 => summary_item(5, "review_count" => [ 1 ], "percent_positive" => 90),
      6 => summary_item(6, "review_count" => "12x", "percent_positive" => 90),
      7 => summary_item(7, "review_count" => 2**40, "percent_positive" => 90),
      8 => summary_item(8, "review_count" => "900", "percent_positive" => "93"),
      9 => summary_item(9, "review_count" => 12, "percent_positive" => 150),
      10 => summary_item(10, "review_count" => 900, "percent_positive" => 93.5).merge("reviews" => { "summary_filtered" => "x", "note\u0000" => "a\u0000b" })
    )

    assert review_page(run).success?

    assert_equal({
      1 => [ 900, nil, "malformed_reviews" ], 2 => [ 900, nil, "malformed_reviews" ], 3 => [ 900, nil, "malformed_reviews" ],
      4 => [ 900, nil, "malformed_reviews" ], 5 => [ nil, 90, "malformed_reviews" ], 6 => [ nil, 90, "malformed_reviews" ],
      7 => [ nil, 90, "malformed_reviews" ], 8 => [ 900, 93, nil ], 9 => [ 12, nil, "too_few_reviews" ], 10 => [ 0, nil, "too_few_reviews" ]
    }, Steam::App.order(:appid).pluck(:appid, :review_count, :review_percent_positive, :review_exclusion).to_h { |appid, *rest| [ appid, rest ] })
    assert_equal({ "summary_filtered" => "x", "note" => "ab" }, Steam::App.find_by!(appid: 10).reviews, "NUL bytes are removed before the jsonb column")
    assert_equal [ 8 ], Steam::App.kept_by(run).pluck(:appid)
    assert_equal [ 10, 1, 9 ], [ run.reload.apps_reviewed, run.apps_kept, run.apps_excluded ]
  end

  test "the database accepts every review exclusion" do
    run = reviews_run
    list(run, 10)

    Steam::ReviewPolicy::EXCLUSIONS.each do |exclusion|
      assert_equal 1, Steam::App.where(appid: 10).update_all(review_exclusion: exclusion), exclusion
    end
  end

  test "the database refuses an unknown exclusion" do
    run = reviews_run
    list(run, 10)

    assert_raises(ActiveRecord::StatementInvalid) { Steam::App.where(appid: 10).update_all(review_exclusion: "other") }
  end
end
