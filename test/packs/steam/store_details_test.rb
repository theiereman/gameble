require "test_helper"
require_relative "../../support/steam_api_stubs"

# The store details of an import run (epic 2, R3, R4, R5): the tags, details
# and genres steps, their policies, the plain text of Steam's store text, and
# the apps a run carried through every step.
class Steam::StoreDetailsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SteamApiStubs

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def run_on(step, last_appid: 0, counts: {})
    Steam::ImportRun.create!(status: :running, step: step, cursor: { "step" => step, "last_appid" => last_appid },
      counts: { "apps_listed" => 0 }.merge(counts), started_at: 1.minute.ago)
  end

  # Apps listed and kept by `run`.
  def keep(run, *appids)
    Steam::App.insert_all(appids.map { |appid| { appid: appid, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, review_count: 900 } })
  end

  # Apps listed, kept and detailed without exclusion by `run`.
  def detail(run, *appids)
    keep(run, *appids)
    Steam::App.where(appid: appids).update_all(details_run_id: run.id, name_en: "Game", release_on: Date.new(2011, 4, 19),
      image_url: "https://example.test/i.jpg", store_url_path: "app/1/")
  end

  def details_page(run, **options)
    Steam::ImportDetailsPage.new(**options).call(import_run_id: run.id, cursor: run.cursor)
  end

  def genres_page(run, **options)
    Steam::ImportGenresPage.new(**options).call(import_run_id: run.id, cursor: run.cursor)
  end

  def ids_of(calls)
    calls.map { |input| input["ids"].map { |id| id["appid"] } }
  end

  # ImportTagsPage

  test "the tags step names the tags in English, upserted on tagid, and hands over to the details" do
    run = run_on("tags")
    Steam::Tag.create!(tagid: 19, name: "Old name")
    calls = stub_get_tag_list(19 => "Action", 492 => "Indie")

    result = Steam::ImportTagsPage.new.call(import_run_id: run.id, cursor: run.cursor)

    assert result.success?
    assert_equal [ "english" ], calls.map { |params| params["language"] }
    assert_equal({ 19 => "Action", 492 => "Indie" }, Steam::Tag.order(:tagid).pluck(:tagid, :name).to_h)
    run.reload
    assert_predicate run, :running?
    assert_equal 2, run.tags_named
    assert_equal({ "step" => "details", "last_appid" => 0 }, run.cursor)
    assert_equal [ Steam::TagsPageImported, Steam::ImportStepFinished ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 0 }, events_of(run).first.data)
  end

  test "tags_named counts the tags upserted, a tagid named twice once" do
    run = run_on("tags")
    client = Steam::WebApi.new
    client.define_singleton_method(:get_tag_list) { |**| [ { tagid: 19, name: "Action" }, { tagid: 19, name: "Action" }, { tagid: 492, name: "Indie" } ] }

    Steam::ImportTagsPage.new(client: client).call(import_run_id: run.id, cursor: run.cursor)

    assert_equal 2, run.reload.tags_named
    assert_equal 2, Steam::Tag.count
  end

  test "a tags page whose cursor moved meanwhile writes nothing" do
    run = run_on("tags")
    stub_get_tag_list
    client = Steam::WebApi.new
    client.define_singleton_method(:get_tag_list) do |**args|
      tags = super(**args)
      Steam::ImportRun.where(id: run.id).update_all(step: "details", cursor: { "step" => "details", "last_appid" => 0 })
      tags
    end

    assert_equal :not_running, Steam::ImportTagsPage.new(client: client).call(import_run_id: run.id, cursor: run.cursor).failure
    assert_empty Steam::Tag.all
    assert_empty events_of(run)
  end

  test "a tags page whose cursor changed on the same step fails with cursor_moved" do
    run = run_on("tags")
    stub_get_tag_list
    client = Steam::WebApi.new
    client.define_singleton_method(:get_tag_list) do |**args|
      tags = super(**args)
      Steam::ImportRun.where(id: run.id).update_all(cursor: { "step" => "tags", "last_appid" => 1 })
      tags
    end

    assert_equal :cursor_moved, Steam::ImportTagsPage.new(client: client).call(import_run_id: run.id, cursor: run.cursor).failure
    assert_empty Steam::Tag.all
  end

  test "an empty or malformed tag list raises and leaves the run on the tags" do
    run = run_on("tags")
    stub_get_tag_list({})

    assert_raises(Steam::WebApi::Error) { Steam::ImportTagsPage.new.call(import_run_id: run.id, cursor: run.cursor) }

    assert_equal "tags", run.reload.step
    assert_empty Steam::Tag.all
  end

  test "a stale reviews cursor once the run is on the tags fails with cursor_moved and calls nothing" do
    run = run_on("tags")
    calls = stub_get_tag_list

    result = Steam::ImportTagsPage.new.call(import_run_id: run.id, cursor: { "step" => "reviews", "last_appid" => 0 })

    assert_equal :cursor_moved, result.failure
    assert_empty calls
  end

  test "a tags page for a run on another step or not running fails with not_running" do
    assert_equal :not_running, Steam::ImportTagsPage.new.call(import_run_id: run_on("reviews").id).failure
    assert_equal :not_found, Steam::ImportTagsPage.new.call(import_run_id: -1).failure
  end

  # ImportDetailsPage

  test "a kept game gets every field in both languages and is not excluded" do
    run = run_on("details", counts: { "apps_detailed" => 4, "apps_excluded_details" => 1 })
    keep(run, 620)
    english = detailed_item(620, name: "Portal 2", description: "<b>Fun</b> &amp; games",
      release: { "steam_release_date" => 1_303_171_200, "original_release_date" => 0 },
      publishers: [ "Valve", "", "Electronic Arts" ],
      tags: [ { "tagid" => 1664, "weight" => 500 }, { "tagid" => 492, "weight" => 900 }, { "tagid" => 19, "weight" => 500 } ])
    calls = stub_get_items_by_language("english" => { 620 => english }, "french" => { 620 => french_item(620, name: "Portal 2", description: "&quot;x&quot;") })

    result = details_page(run, page_size: 3)

    assert result.success?
    data_request = { "include_basic_info" => true, "include_assets" => true, "include_release" => true, "include_tag_count" => 20 }
    assert_equal [
      { "ids" => [ { "appid" => 620 } ], "context" => { "language" => "english", "country_code" => "US" }, "data_request" => data_request },
      { "ids" => [ { "appid" => 620 } ], "context" => { "language" => "french", "country_code" => "US" }, "data_request" => data_request }
    ], calls

    app = Steam::App.find_by!(appid: 620)
    assert_nil app.details_exclusion
    assert_equal run.id, app.details_run_id
    assert_equal [ "Portal 2", "Portal 2" ], [ app.name_en, app.name_fr ]
    assert_equal [ "Fun & games", "\"x\"" ], [ app.short_description_en, app.short_description_fr ]
    assert_equal [ "Valve", "Electronic Arts" ], app.publishers
    assert_equal Date.new(2011, 4, 19), app.release_on
    assert_equal [ 492, 19, 1664 ], app.tag_ids, "by weight, ties by tagid"
    assert_equal "app/620/Portal_2/", app.store_url_path
    assert_equal "https://store.steampowered.com/app/620/Portal_2/", app.store_url
    assert_equal "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg?t=1745363004", app.image_url
    assert_equal english["assets"], app.details["assets"]
    assert_equal({ "name" => "Portal 2", "short_description" => "&quot;x&quot;" }, app.details["french"])
    assert_equal [ 620 ], Steam::App.detailed_by(run).pluck(:appid)

    run.reload
    assert_equal({ "step" => "details", "last_appid" => 620 }, run.cursor)
    assert_equal [ 5, 1 ], [ run.apps_detailed, run.apps_excluded_details ]
    assert_equal [ Steam::DetailsPageImported ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 620 }, events_of(run).first.data)
  end

  test "a hashed capsule is served from the format with that file" do
    item = detailed_item(10, capsule: "ab12cd34/library_capsule.jpg")

    verdict = Steam::DetailsPolicy.verdict(10, item, nil)

    assert_equal "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/10/ab12cd34/library_capsule.jpg?t=1745363004", verdict.image_url
  end

  test "each game that cannot become a card is excluded, the first match winning" do
    run = run_on("details")
    keep(run, 1, 2, 3, 4, 5, 6, 7, 8, 9)
    english = {
      1 => nil,
      2 => unavailable_item(2),
      3 => detailed_item(3, type: 1),
      4 => detailed_item(4, type: nil),
      5 => detailed_item(5, name: " "),
      6 => detailed_item(6, capsule: nil),
      7 => detailed_item(7, release: { "steam_release_date" => 0, "original_release_date" => 0, "original_steam_release_date" => 0 }),
      8 => detailed_item(8, type: 1, capsule: nil),
      9 => detailed_item(9)
    }
    stub_get_items_by_language("english" => english, "french" => {})

    details_page(run)

    assert_equal({ 1 => "unavailable", 2 => "unavailable", 3 => "not_a_game", 4 => "not_a_game", 5 => "no_title",
      6 => "no_vertical_image", 7 => "no_release_date", 8 => "not_a_game", 9 => nil },
      Steam::App.order(:appid).pluck(:appid, :details_exclusion).to_h)
    assert_equal [ 9 ], Steam::App.detailed_by(run).pluck(:appid)
    assert_equal [ 9, 8 ], [ run.reload.apps_detailed, run.apps_excluded_details ]
  end

  test "a French item missing, unsuccessful or blank falls back to the English values" do
    run = run_on("details")
    keep(run, 1, 2, 3)
    english = [ 1, 2, 3 ].index_with { |appid| detailed_item(appid, name: "Game #{appid}", description: "English #{appid}") }
    french = { 1 => nil, 2 => unavailable_item(2), 3 => french_item(3, name: "", description: " <br> ") }
    stub_get_items_by_language("english" => english, "french" => french)

    details_page(run)

    Steam::App.order(:appid).each do |app|
      assert_equal [ "Game #{app.appid}", "English #{app.appid}" ], [ app.name_fr, app.short_description_fr ], app.appid
      assert_nil app.details_exclusion
    end
  end

  test "the release date is the earliest non-zero one; a date before Steam is kept" do
    item = detailed_item(1, release: { "steam_release_date" => 1_303_171_200, "original_release_date" => 0, "original_steam_release_date" => 1_190_000_000 })
    assert_equal Date.new(2007, 9, 17), Steam::DetailsPolicy.verdict(1, item, nil).release_on

    item = detailed_item(1, release: { "steam_release_date" => 1_303_171_200, "original_release_date" => 591_062_400 })
    assert_equal Date.new(1988, 9, 24), Steam::DetailsPolicy.verdict(1, item, nil).release_on
  end

  test "a details page takes the next 100 games kept by this run after the cursor; an app the run did not keep is left alone" do
    run = run_on("details", last_appid: 5)
    keep(run, *(1..120).to_a.reverse)
    Steam::App.where(appid: 50).update_all(review_exclusion: "too_few_reviews")
    calls = stub_get_items_by_language("english" => (1..120).index_with { |appid| detailed_item(appid) }, "french" => {})

    details_page(run)

    expected = (6..106).to_a - [ 50 ]
    assert_equal [ expected, expected ], ids_of(calls)
    assert_equal expected, Steam::App.where(details_run_id: run.id).order(:appid).pluck(:appid)
    assert_equal 106, run.reload.last_appid
  end

  test "with no kept game after the cursor, the details step finishes without calling Steam and hands over to the genres" do
    run = run_on("details", last_appid: 20)
    keep(run, 10, 20)
    calls = stub_get_items_by_language({})

    result = details_page(run)

    assert result.success?
    assert_empty calls
    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "genres", "last_appid" => 0 }, run.cursor)
  end

  test "a stale tags job once the run is on the details does nothing" do
    run = run_on("details")
    keep(run, 10)
    calls = stub_get_items_by_language("english" => { 10 => detailed_item(10) })

    assert_equal :cursor_moved, Steam::ImportDetailsPage.new.call(import_run_id: run.id, cursor: { "step" => "tags", "last_appid" => 0 }).failure
    assert_empty calls
  end

  test "a details page whose cursor moved meanwhile writes nothing" do
    run = run_on("details")
    keep(run, 10)
    stub_get_items_by_language("english" => { 10 => detailed_item(10) })
    client = Steam::WebApi.new
    client.define_singleton_method(:get_items) do |**args|
      items = super(**args)
      Steam::ImportRun.where(id: run.id).update_all(cursor: { "step" => "details", "last_appid" => 10 })
      items
    end

    assert_equal :cursor_moved, details_page(run, client: client).failure
    assert_nil Steam::App.find_by!(appid: 10).details_run_id
  end

  test "a details page for a run on another step, unknown, or not running fails" do
    assert_equal :not_running, Steam::ImportDetailsPage.new.call(import_run_id: run_on("tags").id).failure
    assert_equal :not_found, Steam::ImportDetailsPage.new.call(import_run_id: -1).failure
    assert_equal :not_running, Steam::ImportDetailsPage.new.call(import_run_id: Steam::ImportRun.create!(status: :failed, step: "details").id).failure
  end

  test "the database refuses an unknown details or genres exclusion" do
    run = run_on("details")
    keep(run, 10)

    assert_raises(ActiveRecord::StatementInvalid) { Steam::App.where(appid: 10).update_all(details_exclusion: "other") }
    assert_raises(ActiveRecord::StatementInvalid) { Steam::App.where(appid: 10).update_all(genres_exclusion: "not_a_game") }
  end

  # ImportGenresPage

  test "a genres page asks the store one game at a time and stores genres, credit and the raw data" do
    run = run_on("genres", counts: { "apps_genred" => 3, "apps_excluded_genres" => 1 })
    detail(run, 10, 20)
    entries = { 10 => app_details_entry(10, genres: [ "Action", "Free to Play", "Massively Multiplayer" ], legal_notice: "&copy; Valve<br>All rights"),
                20 => app_details_entry(20, genres: [ "Indie" ]) }
    calls = stub_app_details(entries)

    result = genres_page(run)

    assert result.success?
    assert_equal [ { "appids" => "10", "cc" => "us", "l" => "english", "filters" => "basic,genres" },
                   { "appids" => "20", "cc" => "us", "l" => "english", "filters" => "basic,genres" } ], calls
    app = Steam::App.find_by!(appid: 10)
    assert_equal %w[action free_to_play massively_multiplayer], app.genres
    assert_equal "© Valve All rights", app.credit
    assert_equal entries[10]["data"], app.app_details
    assert_equal [ run.id, nil ], [ app.genres_run_id, app.genres_exclusion ]
    assert_equal [ 10, 20 ], Steam::App.ready_by(run).order(:appid).pluck(:appid)

    run.reload
    assert_equal({ "step" => "genres", "last_appid" => 20 }, run.cursor)
    assert_equal [ 5, 1 ], [ run.apps_genred, run.apps_excluded_genres ]
    assert_equal [ Steam::GenresPageImported ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id, last_appid: 20 }, events_of(run).first.data)
  end

  test "a game without genres gets none; a blank notice no credit; a long one is cut at a word under 1,000 characters" do
    run = run_on("genres")
    detail(run, 10, 20, 30)
    long_notice = ([ "word" ] * 600).join(" ")
    stub_app_details(10 => app_details_entry(10, genres: nil), 20 => app_details_entry(20, legal_notice: " <br> "),
      30 => app_details_entry(30, legal_notice: long_notice))

    genres_page(run)

    apps = Steam::App.order(:appid).index_by(&:appid)
    assert_equal [ [], nil ], [ apps[10].genres, apps[20].credit ]
    credit = apps[30].credit
    assert_operator credit.length, :<=, 1_000
    assert_match(/\Aword( word)*…\z/, credit)
    assert_equal [ 10, 20, 30 ], Steam::App.ready_by(run).order(:appid).pluck(:appid)
  end

  test "the store refusing a game, or answering for another, makes it unavailable" do
    run = run_on("genres")
    detail(run, 10, 20)
    stub_app_details(10 => { "success" => false }, 20 => app_details_entry(21))

    genres_page(run)

    assert_equal({ 10 => "unavailable", 20 => "unavailable" }, Steam::App.order(:appid).pluck(:appid, :genres_exclusion).to_h)
    assert_equal [ [ nil, nil, nil ] ] * 2, Steam::App.order(:appid).pluck(:genres, :credit, :app_details), "not fetched: NULL, not []"
    assert_equal [ run.id ] * 2, Steam::App.pluck(:genres_run_id)
    assert_empty Steam::App.ready_by(run)
    assert_equal [ 2, 2 ], [ run.reload.apps_genred, run.apps_excluded_genres ]
  end

  [ :null, :missing, :not_json ].each do |answer|
    test "a #{answer} appdetails answer raises and leaves the page as it was" do
      run = run_on("genres")
      detail(run, 10)
      stub_app_details(10 => answer)

      assert_raises(Steam::StoreApi::Error) { genres_page(run) }

      assert_nil Steam::App.find_by!(appid: 10).genres_run_id
      assert_equal 0, run.reload.last_appid
    end
  end

  test "a genres page whose cursor moved meanwhile writes nothing" do
    run = run_on("genres")
    detail(run, 10)
    stub_app_details(10 => app_details_entry(10))
    client = Steam::StoreApi.new
    client.define_singleton_method(:app_details) do |appid|
      entry = super(appid)
      Steam::ImportRun.where(id: run.id).update_all(cursor: { "step" => "genres", "last_appid" => 10 })
      entry
    end

    assert_equal :cursor_moved, genres_page(run, client: client).failure
    assert_nil Steam::App.find_by!(appid: 10).genres_run_id
    assert_empty events_of(run)
  end

  test "a genres page takes the next 5 games detailed by this run, never one it excluded" do
    run = run_on("genres")
    detail(run, *(1..8).to_a)
    Steam::App.where(appid: 2).update_all(details_exclusion: "no_vertical_image")
    calls = stub_app_details((1..8).index_with { |appid| app_details_entry(appid) })

    genres_page(run)

    assert_equal %w[1 3 4 5 6], calls.map { |params| params["appids"] }
    assert_equal 6, run.reload.last_appid
  end

  test "with no detailed game after the cursor, the genres step completes the run without calling the store" do
    run = run_on("genres", last_appid: 10)
    detail(run, 10)
    calls = stub_app_details({})

    assert genres_page(run).success?

    assert_empty calls
    assert_predicate run.reload, :completed?
    assert_equal [ Steam::ImportStepFinished, Steam::ImportRunFinished ], events_of(run).map(&:class)
  end

  test "a stale details job once the run is on the genres does nothing" do
    run = run_on("genres")
    detail(run, 10)
    calls = stub_app_details(10 => app_details_entry(10))

    assert_equal :cursor_moved, Steam::ImportGenresPage.new.call(import_run_id: run.id, cursor: { "step" => "details", "last_appid" => 0 }).failure
    assert_empty calls
  end

  test "a genres page for a run on another step or unknown fails" do
    assert_equal :not_running, Steam::ImportGenresPage.new.call(import_run_id: run_on("details").id).failure
    assert_equal :not_found, Steam::ImportGenresPage.new.call(import_run_id: -1).failure
  end

  # ready_by

  test "a game detailed by an earlier run, not kept by this one, is not ready by it" do
    earlier = Steam::ImportRun.create!(status: :completed, step: "genres")
    detail(earlier, 10)
    Steam::App.where(appid: 10).update_all(genres_run_id: earlier.id)
    run = run_on("genres")
    Steam::App.where(appid: 10).update_all(import_run_id: run.id, reviewed_run_id: run.id, review_exclusion: "too_few_reviews")

    assert_empty Steam::App.ready_by(run)
    assert_empty Steam::App.detailed_by(run)
  end

  # PlainText

  test "plain text decodes entities and turns line breaks and block ends into spaces" do
    assert_equal "Fun & games", Steam::PlainText.call("<b>Fun</b> &amp; games")
    assert_equal "Valve All", Steam::PlainText.call("Valve<br>All")
    assert_equal "\"x\"", Steam::PlainText.call("&quot;x&quot;")
    assert_equal "One Two Three", Steam::PlainText.call("<p>One</p><p>Two</p><ul><li>Three</li></ul>")
    assert_equal "", Steam::PlainText.call(nil)
  end
end
