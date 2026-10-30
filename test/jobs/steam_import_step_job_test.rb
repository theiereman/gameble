require "test_helper"
require_relative "../support/steam_api_stubs"

# The import job: one page per job, the next page enqueued after the
# commit, each step handing over to the next, the run failed once retries are
# spent (the waits between attempts well below a stall), and a resumed run
# going on from its cursor without duplicates.
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

  test "the pages follow one another, the app list hands over to the review pass, and the run goes through every step to the end" do
    stub_get_tag_list
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: true)
    stub_app_list_page(after: 20, appids: [ 30, 40 ], more: true)
    stub_app_list_page(after: 40, appids: [ 50 ], more: false)
    calls = stub_get_items(10 => reviewed_item(10, 500), 20 => reviewed_item(20, 499), 30 => unreviewed_item(30), 40 => nil, 50 => reviewed_item(50, 80_000))

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :ready?
    assert_equal "cards", run.step
    assert_equal 5, run.apps_listed
    assert_equal 5, run.apps_reviewed
    assert_equal 2, run.apps_kept
    assert_equal 3, run.apps_excluded
    assert_equal({ "step" => "cards", "last_appid" => 0 }, run.cursor, "review items carry no type: no game reached the cards")
    assert_equal [ 0, 0 ], [ run.cards_written, run.cards_refused ]
    assert_equal [ 2, 2 ], [ run.apps_detailed, run.apps_excluded_details ]
    assert_equal 3, calls.size, "one review page, then one details page in English and in French"
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

  test "a reviews page reviews 100 apps and enqueues the next; an empty page hands over to the tags" do
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

    clear_enqueued_jobs
    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "tags", "last_appid" => 0 } ]) do
      Steam::ImportStepJob.perform_now(run.id, run.reload.cursor)
    end
    assert_equal 2, calls.size
    run.reload
    assert_predicate run, :running?
    assert_equal "tags", run.step
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
    assert_includes message, "Steam::WebApi::Unavailable"
    assert_includes message, "503"
    assert_not_includes message, API_KEY
    assert_equal 1, run.error_messages.size
  end

  test "the waits between a page job's attempts add up to well below a stall, and the run fails after the last" do
    freeze_time
    stub_app_list_status(503, after: 0)

    run = perform_enqueued_jobs { start_run }

    # The first attempt runs at once; each retry is scheduled after a wait.
    attempts = performed_jobs.select { it[:job] == Steam::ImportStepJob }
    assert_equal Steam::ImportStepJob::ATTEMPTS, attempts.size
    waits = attempts.drop(1).map { it.fetch(:at) - Time.current.to_f }
    assert waits.all?(&:positive?), "every retry waits"
    assert_operator waits.sum, :<, Steam::StalledImportRuns::STALL_AFTER.to_f,
      "the waits between attempts stay below Steam::StalledImportRuns::STALL_AFTER"
    assert_predicate run.reload, :failed?
  end

  test "a resumed run goes on from its cursor, and a page fetched twice leaves no duplicate" do
    stub_app_list_page(after: 0, appids: [ 10, 20 ], more: true)
    stub_app_list_status(500, after: 20)
    run = perform_enqueued_jobs { start_run }
    assert_predicate run.reload, :failed?

    # Resumed, the run asks again for the page after its committed cursor.
    steam_stubs.clear
    stub_get_tag_list
    stub_app_list_page(after: 20, appids: [ 30, 40 ], more: true)
    stub_app_list_page(after: 40, appids: [ 50 ], more: false)
    stub_get_items([ 10, 20, 30, 40, 50 ].index_with { |appid| reviewed_item(appid, 1000) })
    perform_enqueued_jobs { Steam::ResumeImport.new.call(import_run_id: run.id) }

    run.reload
    assert_predicate run, :ready?
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
    stub_get_tag_list
    stub_get_items(10 => reviewed_item(10, 800), 20 => reviewed_item(20, 12))
    perform_enqueued_jobs { Steam::ResumeImport.new.call(import_run_id: run.id) }

    run.reload
    assert_predicate run, :ready?
    assert_equal [ 10 ], Steam::App.kept_by(run).pluck(:appid)
  end

  test "a stale reviews job once the run is on the tags does nothing" do
    run = Steam::ImportRun.create!(status: :running, step: "tags", cursor: { "step" => "tags", "last_appid" => 0 }, started_at: 1.minute.ago)
    calls = stub_get_tag_list

    assert_no_enqueued_jobs { Steam::ImportStepJob.perform_now(run.id, { "step" => "reviews", "last_appid" => 0 }) }

    assert_empty calls
    assert_equal "tags", run.reload.step
  end

  test "the tags page enqueues the first details page, which enqueues the first cards page once no game is left" do
    run = Steam::ImportRun.create!(status: :running, step: "tags", cursor: { "step" => "tags", "last_appid" => 0 }, started_at: 1.minute.ago)
    stub_get_tag_list

    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "details", "last_appid" => 0 } ]) do
      Steam::ImportStepJob.perform_now(run.id, run.cursor)
    end
    clear_enqueued_jobs
    assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "cards", "last_appid" => 0 } ]) do
      Steam::ImportStepJob.perform_now(run.id, run.reload.cursor)
    end
  end

  test "a full stubbed run keeps only the normal game ready, with all its card fields" do
    stub_app_list_page(after: 0, appids: [ 10, 20, 30 ], more: false)
    stub_get_tag_list(19 => "Action", 492 => "Indie", 1664 => "Puzzle", 1663 => "FPS")
    tags = [ { "tagid" => 492, "weight" => 1200 }, { "tagid" => 1664, "weight" => 900 }, { "tagid" => 1663, "weight" => 700 } ]
    english = { 10 => detailed_item(10, tags:, reviews: 9_000), 20 => detailed_item(20, type: 4, reviews: 9_000),
      30 => detailed_item(30, capsule: nil, reviews: 9_000) }
    stub_get_items_by_language("english" => english, "french" => { 10 => french_item(10) })

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :ready?
    assert_equal [ 4, 3, 2 ], [ run.tags_named, run.apps_detailed, run.apps_excluded_details ]
    app = Steam::App.ready_by(run).sole
    assert_equal 10, app.appid
    assert_equal [ "The best game 10.", "Le meilleur jeu 10." ], [ app.short_description_en, app.short_description_fr ]
    assert_equal [ [ "Publisher 10" ], [ 492, 1664, 1663 ] ], [ app.publishers, app.tag_ids ]
    assert [ app.name_en, app.name_fr, app.release_on, app.store_url, app.image_url ].all?(&:present?)
    assert_equal [ 1, 0 ], [ run.cards_written, run.cards_refused ]
    assert_nil Catalog::DraftSeason.call
    card = Catalog::StagedCardSeason.where(batch_token: run.token).sole.card
    assert_equal [ "steam:10", %w[puzzle fps] ], [ card.source_key, card.genres ]
  end

  # Replaces the prestige formula for the block.
  def with_formula(formula)
    original = Steam::PrestigeScore.method(:call)
    Steam::PrestigeScore.define_singleton_method(:call, &formula)
    yield
  ensure
    Steam::PrestigeScore.define_singleton_method(:call, original)
  end

  # Records the Steam answers of a full run over `appids`, each with `reviews` reviews.
  def record_run(appids, reviews:)
    steam_stubs.clear
    stub_get_tag_list
    stub_app_list_page(after: 0, appids:, more: false)
    stub_get_items_by_language("english" => appids.index_with { |appid| detailed_item(appid, reviews: reviews.fetch(appid)) }, "french" => {})
  end

  def promote(run)
    assert Steam::PromoteImport.new.call(import_run_id: run.id).success?
  end

  def draft_scores
    Catalog::DraftSeason.call.card_seasons.joins(:card).order("catalog_cards.source_key").pluck("catalog_cards.source_key", :prestige_score).to_h
  end

  test "a second import over other games leaves the draft as it was until promoted, then with exactly its cards, scored with its formula" do
    reviews = { 10 => 1_000, 20 => 5_000, 30 => 50_000 }
    record_run([ 10, 20 ], reviews:)
    first = perform_enqueued_jobs { start_run }
    assert_predicate first.reload, :ready?
    assert_nil Catalog::DraftSeason.call
    promote(first)
    assert_equal %w[steam:10 steam:20], draft_scores.keys

    record_run([ 20, 30 ], reviews:)
    second = with_formula(->(percent_positive:, review_count:) { review_count.fdiv(1_000_000) }) do
      run = perform_enqueued_jobs { start_run }
      assert_equal %w[steam:10 steam:20], draft_scores.keys
      run
    end

    second.reload
    assert_predicate second, :ready?
    assert_equal [ 2, 0 ], [ second.cards_written, second.cards_refused ]
    promote(second)
    expected = [ 20, 30 ].to_h { |appid| [ "steam:#{appid}", reviews.fetch(appid).fdiv(1_000_000) ] }
    assert_equal expected.keys, draft_scores.keys
    expected.each { |key, score| assert_in_delta score, draft_scores.fetch(key), 1e-9, key }
    assert_predicate Catalog::Card.find_by(source_key: "steam:10"), :present?, "a card the draft lost keeps its row"
  end

  test "a full stubbed run with a repeated appid and a malformed review percent is ready, the malformed app without a card" do
    stub_get_tag_list
    apps = [ 10, 10, 20, 30 ].map { |appid| { "appid" => appid, "name" => "Game #{appid}" } }
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=0") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => apps } }.to_json ]
    end
    english = [ 10, 20, 30 ].index_with { |appid| detailed_item(appid, reviews: 9_000) }
    english[20]["reviews"]["summary_filtered"]["percent_positive"] = 150
    stub_get_items_by_language("english" => english, "french" => {})

    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :ready?
    promote(run)
    assert_equal [ 10, 20, 30 ], Steam::App.order(:appid).pluck(:appid)
    assert_equal 1, Steam::App.where(appid: 10).count
    assert_equal [ 3, 3, 2, 1 ], [ run.apps_listed, run.apps_reviewed, run.apps_kept, run.apps_excluded ]
    assert_equal [ nil, "malformed_reviews" ], Steam::App.find_by!(appid: 20).slice(:review_percent_positive, :review_exclusion).values
    assert_equal %w[steam:10 steam:30], draft_scores.keys
    assert_nil Catalog::Card.find_by(source_key: "steam:20")
    assert_includes run.latest_errors.map(&:message), "appid 10: repeated_in_page"
  end

  # Each game's tags, heaviest first: [ tagid, weight ] pairs.
  GENRE_TAGS = {
    1 => [ [ 492, 1200 ], [ 1664, 900 ], [ 1663, 800 ] ],
    2 => [ [ 1663, 500 ], [ 122, 900 ], [ 19, 950 ] ],
    3 => [ [ 999_999, 2000 ], [ 122, 10 ] ],
    4 => [ [ 19, 900 ], [ 492, 1200 ] ]
  }.freeze

  test "a full stubbed run goes through every step without the store API, and each card's main theme after publish is its most-voted theme" do
    appids = (1..21).to_a
    stub_app_list_page(after: 0, appids:, more: false)
    stub_get_tag_list(19 => "Action", 492 => "Indie", 1664 => "Puzzle", 1663 => "FPS", 122 => "RPG")
    english = appids.index_with do |appid|
      tags = GENRE_TAGS.fetch(appid, [ [ 19, 900 ], [ 492, 1200 ], [ 122, 100 ] ]).map { |tagid, weight| { "tagid" => tagid, "weight" => weight } }
      detailed_item(appid, tags:, reviews: 500 + (appid * 1_000))
    end
    calls = stub_get_items_by_language("english" => english, "french" => {})

    # Every request is answered by a stub above, or raises and fails the run:
    # a completed run made no other request (no store API).
    run = perform_enqueued_jobs { start_run }

    run.reload
    assert_predicate run, :ready?
    promote(run)
    assert_equal 3, calls.size, "one review page, then one details page in English and in French"
    finished = Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).of_type(Steam::ImportStepFinished).map { |event| event.data[:step] }
    assert_equal %w[app_list reviews tags details cards], finished
    assert_equal [ 21, 0 ], [ run.cards_written, run.cards_refused ]

    draft = Catalog::DraftSeason.call
    assert Catalog::PublishSeason.new.call(number: draft.number).success?

    main_themes = Catalog::CardSeason.where(season_id: draft.id).where.not(main_theme: nil).joins(:card)
      .pluck(:main_theme, "catalog_cards.source_key").group_by(&:first).transform_values { |pairs| pairs.map(&:last).sort }
    assert_equal({ "puzzle" => [ "steam:1" ], "rpg" => ([ 2, 3 ] + (5..21).to_a).map { |appid| "steam:#{appid}" }.sort }, main_themes)
    sets = Catalog::Set.where(season_id: draft.id).includes(memberships: { card_season: :card })
      .to_h { |set| [ set.key, set.memberships.map { |membership| membership.card_season.card.source_key }.sort ] }
    assert_equal({ "puzzle" => [ "steam:1" ], "fps" => [ "steam:1", "steam:2" ], "rpg" => ([ 2, 3 ] + (5..21).to_a).map { |appid| "steam:#{appid}" }.sort,
      "ufos" => [ "steam:4" ] }, sets)
  end
end
