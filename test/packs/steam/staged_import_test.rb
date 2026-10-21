require "test_helper"
require_relative "../../support/catalog_seeds"

# The staged import: a run that ends its cards pass waits for promotion, is
# promoted or discarded, and blocks a new run meanwhile.
class Steam::StagedImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CatalogSeeds

  def events_of(run)
    Rails.configuration.event_store.read.stream(Steam::ImportRun.stream_name(run.id)).to_a
  end

  def ready_run(season_number: Catalog::DraftSeasonNumber.call, **attributes)
    Steam::ImportRun.create!(status: :ready, step: "cards", counts: { "cards_written" => 1, "season_number" => season_number },
      started_at: 1.hour.ago, finished_at: 1.minute.ago, **attributes)
  end

  def stage(run, card = nil, score: 0.5)
    card ||= seed_card_seasons([ 0.1 ], prefix: "staged").card_seasons.first.card
    Catalog::StageCardSeason.new.call(batch_token: run.token, card_id: card.id, prestige_score: score, prestige_score_version: 1, rating: 80.0).value!
    card
  end

  test "a new import is refused while a run waits for promotion" do
    run = ready_run

    assert_no_enqueued_jobs { assert_equal :run_awaiting_promotion, Steam::StartImport.new.call.failure }
    assert_equal [ run ], Steam::ImportRun.all.to_a
  end

  test "the database holds one ready run at a time" do
    ready_run

    assert_raises(ActiveRecord::RecordNotUnique) { ready_run }
  end

  test "a new import starts on the draft season it finds, or on the next number" do
    next_number = Catalog::DraftSeasonNumber.call
    assert_equal next_number, Steam::StartImport.new.call.value!.season_number

    Steam::ImportRun.update_all(status: "abandoned")
    draft = seed_card_seasons([ 0.1 ])
    assert_equal draft.number, Steam::StartImport.new.call.value!.season_number
  end

  test "promoting the ready run replaces the draft's cards, promotes the run and publishes one event" do
    draft = seed_card_seasons([ 0.1, 0.2 ])
    run = ready_run
    card = stage(run, draft.card_seasons.first.card, score: 0.9)

    result = Steam::PromoteImport.new.call(import_run_id: run.id)

    assert_equal run, result.value!
    assert_predicate run.reload, :promoted?
    assert_equal({ card.id => 0.9 }, draft.card_seasons.pluck(:card_id, :prestige_score).to_h)
    assert_empty Catalog::StagedCardSeason.where(batch_token: run.token)
    assert_equal [ Steam::ImportRunPromoted ], events_of(run).map(&:class)
    assert_equal({ import_run_id: run.id }, events_of(run).first.data)
    assert_nil Steam::UnfinishedImportRun.call
    assert Steam::StartImport.new.call.success?
  end

  test "promoting a run whose season was published since abandons it and throws its batch away" do
    draft = seed_card_seasons([ 0.1 ])
    run = ready_run(season_number: draft.number)
    stage(run, draft.card_seasons.first.card)
    draft.update!(status: :published, published_at: Time.current)

    assert_equal :stale_batch, Steam::PromoteImport.new.call(import_run_id: run.id).failure

    assert_predicate run.reload, :abandoned?
    assert_empty Catalog::StagedCardSeason.where(batch_token: run.token)
    assert_equal 1, draft.card_seasons.count
    assert_equal [ Steam::ImportRunAbandoned ], events_of(run).map(&:class)
  end

  test "promoting a run that staged nothing is refused and the run stays ready" do
    run = ready_run

    assert_equal :empty_batch, Steam::PromoteImport.new.call(import_run_id: run.id).failure
    assert_predicate run.reload, :ready?
    assert_empty events_of(run)
  end

  test "only a ready run is promoted or discarded" do
    %w[running failed completed promoted abandoned].each do |status|
      run = Steam::ImportRun.create!(status:, step: "cards")

      assert_equal :not_ready, Steam::PromoteImport.new.call(import_run_id: run.id).failure, status
      assert_equal :not_ready, Steam::DiscardImport.new.call(import_run_id: run.id).failure, status
      assert_equal status, run.reload.status
      run.update_columns(status: "abandoned")
    end
    assert_equal :not_found, Steam::PromoteImport.new.call(import_run_id: -1).failure
    assert_equal :not_found, Steam::DiscardImport.new.call(import_run_id: -1).failure
  end

  test "discarding the ready run deletes its batch, abandons it and leaves the draft exactly as it was" do
    draft = seed_card_seasons([ 0.1, 0.2 ])
    before = draft.card_seasons.order(:id).pluck(:id, :card_id, :prestige_score)
    run = ready_run
    stage(run, draft.card_seasons.first.card, score: 0.9)
    stage(run, seed_card_seasons([ 0.3 ], season: draft, prefix: "extra").card_seasons.order(:id).last.card)
    other = Steam::ImportRun.create!(status: :abandoned, step: "cards")
    stage(other, draft.card_seasons.order(:id).last.card)

    assert_equal run, Steam::DiscardImport.new.call(import_run_id: run.id).value!

    assert_predicate run.reload, :abandoned?
    assert_empty Catalog::StagedCardSeason.where(batch_token: run.token)
    assert_equal 1, Catalog::StagedCardSeason.where(batch_token: other.token).count
    assert_equal before, draft.card_seasons.order(:id).pluck(:id, :card_id, :prestige_score).first(2)
    assert_equal [ Steam::ImportRunAbandoned ], events_of(run).map(&:class)
    assert_nil Steam::UnfinishedImportRun.call
  end

  test "a ready run keeps the season from being published" do
    run = ready_run

    assert_equal run, Steam::UnfinishedImportRun.call
  end
end
