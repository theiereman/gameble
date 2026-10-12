require "test_helper"
require_relative "../../support/rake_tasks"

# steam:fill_card_sources: the cards and card-seasons an import wrote before
# they carried developers, franchises and review counts get them from the
# stored Steam apps, without a new import.
class Steam::FillCardSourcesTaskTest < ActiveSupport::TestCase
  include RakeTasks

  setup { rake_task("steam:fill_card_sources") }

  def fill_card_sources
    capture_io { rake_task("steam:fill_card_sources").execute }.first
  end

  def details(developer, franchise)
    { "basic_info" => { "developers" => [ { "name" => developer } ], "franchises" => [ { "name" => franchise } ] } }
  end

  # Cards for `appids` imported by a completed run, then stripped of what
  # the imports before did not store.
  def imported_before(*appids)
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 },
      counts: { "apps_listed" => 0 }, started_at: 1.minute.ago)
    Steam::App.insert_all(appids.map do |appid|
      { appid:, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id,
        review_count: 1_000 + appid, review_percent_positive: 90, name_en: "Game #{appid}", name_fr: "Jeu #{appid}",
        release_on: Date.new(2011, 4, 19), tag_ids: [], image_url: "https://example.test/#{appid}.jpg",
        details: details("Studio &amp; #{appid}", "Series #{appid}") }
    end)
    Steam::ImportCardsPage.new.call(import_run_id: run.id, cursor: run.reload.cursor)
    Catalog::Card.where("source_key LIKE 'steam:%'").update_all(developers: [], franchises: [])
    Catalog::CardSeason.update_all(review_count: nil)
  end

  def card(appid)
    Catalog::Card.find_by!(source_key: "steam:#{appid}")
  end

  test "a first run fills the cards and every card-season without a count, published ones included; a second changes nothing" do
    imported_before(10, 20)
    published = Catalog::DraftSeason.call
    Catalog::CardSeason.where(season: published).update_all(rarity: 1)
    published.update_columns(status: "published", published_at: Time.current)
    Steam::App.insert_all([ { appid: 30, name: "No card", import_run_id: Steam::ImportRun.last.id, review_count: 5,
      details: details("Elsewhere", "Nothing") } ])

    output = fill_card_sources

    assert_includes output, "2 card(s) and 2 card-season(s) filled"
    assert_equal [ [ "Studio & 10" ], [ "Series 10" ] ], [ card(10).developers, card(10).franchises ]
    assert_equal [ 1_010 ], card(10).card_seasons.pluck(:review_count)
    assert_equal [ 1_020 ], card(20).card_seasons.pluck(:review_count)
    assert_not Catalog::Card.exists?(source_key: "steam:30")

    snapshot = -> { [ Catalog::Card.order(:id).pluck(:developers, :franchises, :updated_at), Catalog::CardSeason.order(:id).pluck(:review_count, :updated_at) ] }
    before = snapshot.call

    assert_includes fill_card_sources, "0 card(s) and 0 card-season(s) filled"
    assert_equal before, snapshot.call
  end

  test "an app whose review count is gone still gives its card the names; its card-seasons keep no count" do
    imported_before(10)
    Steam::App.where(appid: 10).update_all(review_count: nil, review_exclusion: "unavailable")

    assert_includes fill_card_sources, "1 card(s) and 0 card-season(s) filled"
    assert_equal [ [ "Studio & 10" ], [ "Series 10" ] ], [ card(10).developers, card(10).franchises ]
    assert_equal [ nil ], card(10).card_seasons.pluck(:review_count)
  end

  test "apps are walked in batches past the first thousand" do
    imported_before(10)
    Steam::App.insert_all((1_001..2_100).map { |appid| { appid:, name: "Game #{appid}", import_run_id: Steam::ImportRun.last.id, review_count: 1, details: {} } })
    Steam::App.where(appid: 10).update_all(appid: 2_200)
    Catalog::Card.where(source_key: "steam:10").update_all(source_key: "steam:2200")

    assert_includes fill_card_sources, "1 card(s) and 1 card-season(s) filled"
    assert_equal [ "Studio & 10" ], Catalog::Card.find_by!(source_key: "steam:2200").developers
  end
end
