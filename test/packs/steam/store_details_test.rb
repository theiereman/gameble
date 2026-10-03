require "test_helper"
require_relative "../../support/steam_api_stubs"

# The store details of an import run (epic 2, R3, R4, R5): the tags and
# details steps, their policies, the plain text of Steam's store text, and
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
    assert_equal [ 620 ], Steam::App.ready_by(run).pluck(:appid)

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
    assert_equal [ 9 ], Steam::App.ready_by(run).pluck(:appid)
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

  test "a malformed store item never raises: a bad field gives its exclusion or is dropped, NUL bytes are removed" do
    run = run_on("details")
    keep(run, *(1..9).to_a)
    english = {
      1 => detailed_item(1).merge("basic_info" => "not a hash"),
      2 => detailed_item(2).merge("assets" => [ "library_600x900.jpg" ]),
      3 => detailed_item(3, release: { "steam_release_date" => { "t" => 1 } }),
      4 => detailed_item(4, release: { "steam_release_date" => 253_402_300_800 }),
      5 => detailed_item(5, tags: [ { "tagid" => 19, "weight" => [ 1 ] }, { "tagid" => 2**40, "weight" => 5 }, { "tagid" => "x" }, "junk",
        { "tagid" => 492, "weight" => 7 }, { "tagid" => 1664 } ]),
      6 => detailed_item(6, name: "Nul\u0000 game", description: "A\u0000b", publishers: [ "P\u0000ub" ]),
      7 => detailed_item(7).merge("name" => [ "x" ], "release" => "2011", "tags" => { "tagid" => 19 }, "store_url_path" => 7),
      8 => detailed_item(8, release: { "steam_release_date" => 1_303_171_200.5 }),
      9 => detailed_item(9).merge("basic_info" => { "short_description" => [ "x" ], "publishers" => "Valve" })
    }
    french = { 1 => french_item(1).merge("basic_info" => [ 1 ], "name" => { "a" => 1 }), 6 => french_item(6, name: "Jeu\u0000 6") }
    stub_get_items_by_language("english" => english, "french" => french)

    assert details_page(run).success?

    apps = Steam::App.order(:appid).index_by(&:appid)
    assert_equal({ 1 => nil, 2 => "no_vertical_image", 3 => "no_release_date", 4 => "no_release_date", 5 => nil, 6 => nil,
      7 => "no_title", 8 => "no_release_date", 9 => nil }, apps.transform_values(&:details_exclusion))
    assert_equal [ "Game 1", "Game 1", nil, nil, [] ], [ apps[1].name_en, apps[1].name_fr, apps[1].short_description_en, apps[1].short_description_fr, apps[1].publishers ]
    assert_equal [ 492, 1664 ], apps[5].tag_ids, "a malformed tag is dropped; a missing weight counts 0"
    assert_equal [ "Nul game", "Jeu 6", "Ab", [ "Pub" ] ], [ apps[6].name_en, apps[6].name_fr, apps[6].short_description_en, apps[6].publishers ]
    assert_not_includes apps[6].details.to_json, "\\u0000"
    assert_equal [ [], "app/7/" ], [ apps[7].tag_ids, apps[7].store_url_path ]
    assert_equal [ nil, [] ], [ apps[9].short_description_en, apps[9].publishers ]
    assert_equal [ 9, 5 ], [ run.reload.apps_detailed, run.apps_excluded_details ]
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

  test "with no kept game after the cursor, the details step finishes without calling Steam and hands over to the cards" do
    run = run_on("details", last_appid: 20)
    keep(run, 10, 20)
    calls = stub_get_items_by_language({})

    result = details_page(run)

    assert result.success?
    assert_empty calls
    run.reload
    assert_predicate run, :running?
    assert_equal({ "step" => "cards", "last_appid" => 0 }, run.cursor)
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

  test "the database refuses an unknown details exclusion" do
    run = run_on("details")
    keep(run, 10)

    assert_raises(ActiveRecord::StatementInvalid) { Steam::App.where(appid: 10).update_all(details_exclusion: "other") }
  end

  # ready_by

  test "a game kept and detailed by the run without exclusion is ready by it; one it excluded at the details is not" do
    run = run_on("cards")
    detail(run, 10, 20)
    Steam::App.where(appid: 20).update_all(details_exclusion: "no_vertical_image")

    assert_equal [ 10 ], Steam::App.ready_by(run).pluck(:appid)
  end

  test "a game detailed by an earlier run, not kept by this one, is not ready by it" do
    earlier = Steam::ImportRun.create!(status: :completed, step: "cards")
    detail(earlier, 10)
    run = run_on("cards")
    Steam::App.where(appid: 10).update_all(import_run_id: run.id, reviewed_run_id: run.id, review_exclusion: "too_few_reviews")

    assert_empty Steam::App.ready_by(run)
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
