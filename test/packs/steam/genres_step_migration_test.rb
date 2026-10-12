require "test_helper"
require Rails.root.join("db/migrate/20261003040000_move_import_runs_off_the_genres_step").to_s

# The data migration of story 2.10: a run left on the removed genres step
# moves to the cards step, cursor 0, and a resume writes its cards.
class Steam::GenresStepMigrationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def migrate
    ActiveRecord::Migration.suppress_messages { MoveImportRunsOffTheGenresStep.new.migrate(:up) }
  end

  # A failed run left on the genres step, as the step's validation now refuses.
  def legacy_run
    run = Steam::ImportRun.create!(status: :failed, step: "details", cursor: { "step" => "details", "last_appid" => 0 },
      started_at: 1.hour.ago, finished_at: 1.minute.ago)
    run.update_columns(step: "genres", cursor: { "step" => "genres", "last_appid" => 20 })
    run
  end

  def ready(run, *appids)
    Steam::App.insert_all(appids.map do |appid|
      { appid:, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id,
        review_count: 1_000 * appid, review_percent_positive: 90, name_en: "Game #{appid}", name_fr: "Jeu #{appid}",
        publishers: [ "Studio" ], release_on: Date.new(2011, 4, 19), tag_ids: [ 1664 ], store_url_path: "app/#{appid}/",
        image_url: "https://example.test/#{appid}.jpg" }
    end)
  end

  test "a run on the genres step moves to the cards, cursor 0; a run on another step is left alone" do
    run = legacy_run
    other = Steam::ImportRun.create!(status: :completed, step: "cards", cursor: { "step" => "cards", "last_appid" => 30 },
      started_at: 2.hours.ago, finished_at: 2.hours.ago)

    migrate

    assert_equal [ "cards", { "step" => "cards", "last_appid" => 0 } ], [ run.reload.step, run.cursor ]
    assert_predicate run, :failed?
    assert_equal [ "cards", { "step" => "cards", "last_appid" => 30 } ], [ other.reload.step, other.cursor ]
  end

  test "a resumed legacy run writes its cards and completes" do
    run = legacy_run
    ready(run, 10, 20)
    Steam::Tag.insert_all([ { tagid: 1664, name: "Puzzle" } ])
    migrate

    perform_enqueued_jobs { assert Steam::ResumeImport.new.call(import_run_id: run.id).success? }

    run.reload
    assert_predicate run, :completed?
    assert_equal 2, run.cards_written
    assert_equal [ %w[puzzle] ] * 2, Catalog::Card.where(source_key: %w[steam:10 steam:20]).pluck(:genres)
  end
end
