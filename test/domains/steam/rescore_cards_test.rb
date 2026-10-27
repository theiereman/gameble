require "test_helper"
require_relative "../../support/steam_api_stubs"

# Steam::RescoreCards: the latest completed or promoted run stages its cards
# again, so a change of the prestige formula reaches the draft, once the
# result is promoted, without calling Steam.
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
      { appid:, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id,
        review_count: 1_000 * appid, review_percent_positive: 90, name_en: "Game #{appid}", name_fr: "Jeu #{appid}",
        short_description_en: "The game #{appid}.", short_description_fr: "Le jeu #{appid}.", publishers: [ "Studio" ],
        release_on: Date.new(2011, 4, 19), tag_ids: [ 122 ], store_url_path: "app/#{appid}/", image_url: "https://example.test/#{appid}.jpg" }
    end)
  end

  # Runs the pages of `run`, which ends ready, then promotes its batch.
  def run_pages_and_promote(run)
    clear_enqueued_jobs
    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.reload.cursor) }
    assert_predicate run.reload, :ready?
    assert Steam::PromoteImport.new.call(import_run_id: run.id).success?
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

  test "the latest promoted run goes back on its cards step, stages the new formula's scores and is ready again, the draft changing only when promoted, without calling Steam" do
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 },
      counts: { "apps_listed" => 3, "season_number" => Catalog::DraftSeasonNumber.call }, started_at: 1.hour.ago)
    ready(run, 10, 20, 30)
    run_pages_and_promote(run)
    assert_predicate run.reload, :promoted?
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
    assert_predicate run, :ready?
    assert_equal [ 3, 0 ], [ run.cards_written, run.cards_refused ]
    assert_empty run.error_messages
    assert_equal before, draft_scores, "the draft is untouched until the batch is promoted"
    assert_equal 3, Catalog::StagedCardSeason.where(batch_token: run.token).count

    assert Steam::PromoteImport.new.call(import_run_id: run.id).success?
    assert_equal({ "steam:10" => 0.01, "steam:20" => 0.02, "steam:30" => 0.03 }, draft_scores)
    assert_empty Catalog::StagedCardSeason.where(batch_token: run.token)
  end

  test "a draft scored partly by an earlier formula is stamped with the current version by the rescore, and then publishes" do
    Steam::Tag.insert_all([ { tagid: 122, name: "RPG" } ])
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 },
      counts: { "apps_listed" => 3, "season_number" => Catalog::DraftSeasonNumber.call }, started_at: 1.hour.ago)
    ready(run, *1..21)
    run_pages_and_promote(run)
    draft = Catalog::DraftSeason.call
    assert_equal 21, draft.card_seasons.count
    draft.card_seasons.joins(:card).where(catalog_cards: { source_key: "steam:10" }).update_all(prestige_score_version: Steam::PrestigeScore::VERSION - 1)
    assert_equal :mixed_score_versions, Catalog::PublishSeason.new.call(number: draft.number).failure

    rescore(run)
    run_pages_and_promote(run)

    assert_equal [ Steam::PrestigeScore::VERSION ], draft.card_seasons.distinct.pluck(:prestige_score_version)
    assert Catalog::PublishSeason.new.call(number: draft.number).success?
  end

  test "a card the rescore now refuses leaves the draft once the batch is promoted, not before" do
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 },
      counts: { "apps_listed" => 3, "season_number" => Catalog::DraftSeasonNumber.call }, started_at: 1.hour.ago)
    ready(run, 10, 20, 30)
    run_pages_and_promote(run)
    Steam::App.where(appid: 10).update_all(review_percent_positive: 150)

    rescore(run)

    assert_equal %w[steam:10 steam:20 steam:30], draft_scores.keys
    clear_enqueued_jobs
    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.reload.cursor) }

    run.reload
    assert_predicate run, :ready?
    assert_equal [ 2, 1 ], [ run.cards_written, run.cards_refused ]
    assert_equal [ "appid 10: invalid_reviews" ], run.latest_errors.map(&:message)
    assert_equal %w[steam:10 steam:20 steam:30], draft_scores.keys, "the draft is untouched until the pass is promoted"

    assert Steam::PromoteImport.new.call(import_run_id: run.id).success?
    assert_equal %w[steam:20 steam:30], draft_scores.keys
  end

  test "a completed run, from before staging, can be rescored too" do
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    run = completed_run

    assert_enqueued_with(job: Steam::ImportStepJob) { assert rescore(run).success? }
    assert_equal Catalog::DraftSeasonNumber.call, run.reload.season_number
  end

  test "a ready run is refused with run_awaiting_promotion" do
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    run = completed_run(status: :ready)

    assert_no_enqueued_jobs { assert_equal :run_awaiting_promotion, rescore(run).failure }
    assert_predicate run.reload, :ready?
  end

  test "an abandoned run is refused with not_completed" do
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    run = completed_run(status: :abandoned)

    assert_no_enqueued_jobs { assert_equal :not_completed, rescore(run).failure }
    assert_predicate run.reload, :abandoned?
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
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 }, counts: { "apps_listed" => 2, "season_number" => Catalog::DraftSeasonNumber.call }, started_at: 1.hour.ago)
    ready(run, 10, 20)
    run_pages_and_promote(run)
    season = Catalog::DraftSeason.call
    Catalog::CardSeason.where(season:).update_all(rarity: 1)
    season.update_columns(status: "published", published_at: Time.current)
    before = [ run.reload.attributes, Catalog::Season.count, Catalog::CardSeason.count, events_of(run).size ]

    assert_no_enqueued_jobs { assert_equal :already_published, rescore(run).failure }
    assert_equal before, [ run.reload.attributes, Catalog::Season.count, Catalog::CardSeason.count, events_of(run).size ]

    # A draft opened since (by another writer) does not make the run's cards unpublished.
    Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    assert_equal :already_published, rescore(run).failure
  end

  test "a discarded rescore batch restores the run, which can be rescored again" do
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 },
      counts: { "apps_listed" => 3, "season_number" => Catalog::DraftSeasonNumber.call }, started_at: 1.hour.ago)
    ready(run, 10, 20, 30)
    run_pages_and_promote(run)
    before = draft_scores

    assert rescore(run).success?
    run_pages_and_promote_unpromoted = ->(r) do
      clear_enqueued_jobs
      perform_enqueued_jobs { Steam::ImportStepJob.perform_later(r.id, r.reload.cursor) }
    end
    run_pages_and_promote_unpromoted.(run)
    assert_predicate run.reload, :ready?

    assert Steam::DiscardImport.new.call(import_run_id: run.id).success?

    assert_predicate run.reload, :promoted?
    assert_empty Catalog::StagedCardSeason.where(batch_token: run.token)
    assert_equal before, draft_scores
    assert rescore(run).success?
  end

  test "an unknown run is refused with not_found" do
    assert_equal :not_found, Steam::RescoreCards.new.call(import_run_id: -1).failure
  end
end
