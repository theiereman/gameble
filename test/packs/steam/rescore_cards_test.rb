require "test_helper"
require_relative "../../support/steam_api_stubs"

# Steam::RescoreCards (story 2.8): the latest completed run writes its cards
# again, so a change of the prestige formula reaches the draft without
# calling Steam.
class Steam::RescoreCardsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SteamApiStubs

  # Every Steam request meets the empty Faraday stubs and raises.
  setup { stub_steam_api }
  teardown { unstub_steam_api }

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def rescore(run)
    Steam::RescoreCards.new.call(import_run_id: run.id)
  end

  def completed_run(**attributes)
    Steam::ImportRun.create!(status: :completed, step: "cards", cursor: { "step" => "cards", "last_appid" => 30 },
      counts: { "apps_listed" => 3, "cards_written" => 3, "cards_refused" => 0 }, started_at: 1.hour.ago, finished_at: 1.minute.ago, **attributes)
  end

  # Apps carried by `run` through every step.
  def ready(run, *appids)
    Steam::App.insert_all(appids.map do |appid|
      { appid:, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id, genres_run_id: run.id,
        review_count: 1_000 * appid, review_percent_positive: 90, name_en: "Game #{appid}", name_fr: "Jeu #{appid}",
        short_description_en: "The game #{appid}.", short_description_fr: "Le jeu #{appid}.", publishers: [ "Studio" ],
        release_on: Date.new(2011, 4, 19), tag_ids: [], store_url_path: "app/#{appid}/", image_url: "https://example.test/#{appid}.jpg",
        genres: %w[action], credit: "© Studio" }
    end)
  end

  def draft_scores
    Catalog::DraftSeason.call.card_seasons.joins(:card).order("catalog_cards.source_key").pluck("catalog_cards.source_key", :prestige_score).to_h
  end

  # Replaces the prestige formula for the block.
  def with_formula(formula)
    original = Steam::PrestigeScore.method(:call)
    Steam::PrestigeScore.define_singleton_method(:call, &formula)
    yield
  ensure
    Steam::PrestigeScore.define_singleton_method(:call, original)
  end

  test "the latest completed run goes back on its cards step, rewrites the draft's scores with the new formula and completes again, without calling Steam" do
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 }, counts: { "apps_listed" => 3 }, started_at: 1.hour.ago)
    ready(run, 10, 20, 30)
    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }
    assert_predicate run.reload, :completed?
    before = draft_scores
    assert_equal 3, before.size

    with_formula(->(percent_positive:, review_count:) { review_count.fdiv(1_000_000) }) do
      result = nil
      assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "cards", "last_appid" => 0 } ], queue: "import") do
        result = rescore(run)
      end

      assert result.success?
      run.reload
      assert_predicate run, :running?
      assert_equal [ "cards", { "step" => "cards", "last_appid" => 0 }, nil ], [ run.step, run.cursor, run.finished_at ]
      assert_equal [ 0, 0 ], [ run.cards_written, run.cards_refused ]
      assert_equal 1, events_of(run).count { |event| event.is_a?(Steam::CardsRescoreStarted) }
      assert_equal({ import_run_id: run.id }, events_of(run).last.data)

      # The enqueued page, its following pages included.
      clear_enqueued_jobs
      perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }
    end

    run.reload
    assert_predicate run, :completed?
    assert_equal [ 3, 0 ], [ run.cards_written, run.cards_refused ]
    assert_empty run.error_messages
    assert_equal({ "steam:10" => 0.01, "steam:20" => 0.02, "steam:30" => 0.03 }, draft_scores)
    assert_not_equal before, draft_scores
  end

  test "a run that is not the latest is refused with not_latest" do
    older = completed_run(created_at: 2.days.ago)
    completed_run

    assert_no_enqueued_jobs { assert_equal :not_latest, rescore(older).failure }
    assert_predicate older.reload, :completed?
  end

  test "a latest run that has not completed is refused with not_completed" do
    run = Steam::ImportRun.create!(status: :failed, step: "details", started_at: 1.hour.ago, finished_at: 1.minute.ago)

    assert_no_enqueued_jobs { assert_equal :not_completed, rescore(run).failure }
    assert_predicate run.reload, :failed?
    assert_empty events_of(run)
  end

  test "while another run is unfinished the rescore is refused with run_in_progress" do
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    Steam::ImportRun.create!(status: :running, step: "app_list", started_at: 1.day.ago, created_at: 1.day.ago)
    run = completed_run

    assert_no_enqueued_jobs { assert_equal :run_in_progress, rescore(run).failure }
    assert_predicate run.reload, :completed?
  end

  test "once the run's draft is published the rescore is refused with already_published and writes nothing" do
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 }, counts: { "apps_listed" => 2 }, started_at: 1.hour.ago)
    ready(run, 10, 20)
    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.cursor) }
    season = Catalog::DraftSeason.call
    Catalog::CardSeason.where(season:).update_all(rarity: 1, dust_tier: 0)
    season.update_columns(status: "published", published_at: Time.current)
    before = [ run.reload.attributes, Catalog::Season.count, Catalog::CardSeason.count, events_of(run).size ]

    assert_no_enqueued_jobs { assert_equal :already_published, rescore(run).failure }
    assert_equal before, [ run.reload.attributes, Catalog::Season.count, Catalog::CardSeason.count, events_of(run).size ]

    # A draft opened since (by another writer) does not make the run's cards unpublished.
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    assert_equal :already_published, rescore(run).failure
  end

  test "an unknown run is refused with not_found" do
    assert_equal :not_found, Steam::RescoreCards.new.call(import_run_id: -1).failure
  end
end
