module Steam
  # Names Steam's store tags in English (CAP-2, AD-19; epic 2 R4) for a
  # running run on the tags step: one page, one IStoreService/GetTagList call,
  # outside the transaction; then, in one transaction, the tags are upserted
  # on tagid into steam_tags, the tags_named count is set and the step
  # finishes (Steam::FinishImportStep). Only English names are fetched: the
  # cards keep them as keys (Steam::CardMapping), and no story plans labels
  # in other languages.
  #
  # A Steam failure, or an answer that names no tag, raises
  # Steam::WebApi::Error (key redacted), for the job to retry and, once
  # retries are spent, fail the run.
  #
  # `cursor`, when given, is the cursor the caller expects the page to start
  # from; a run that has moved on fails with cursor_moved before the page is
  # read.
  #
  #   Steam::ImportTagsPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportTagsPage < ApplicationOperation
    include PageSteps

    STEP = "tags".freeze
    LANGUAGE = "english".freeze

    def initialize(client: WebApi.new)
      super()
      @client = client
    end

    def call(import_run_id:, cursor: nil)
      run = step find_run(import_run_id)
      step require_on_step(run)
      step require_expected_cursor(run, cursor)
      expected_cursor = run.cursor

      tags = @client.get_tag_list(language: LANGUAGE)

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged(run, expected_cursor)
        named = step upsert_tags(tags)
        run.update!(counts: run.counts.merge("tags_named" => named))
        step publish_page(TagsPageImported, run)
        step FinishImportStep.new.call(import_run: run)
        run
      end
    end

    private

    def upsert_tags(tags)
      rows = tags.uniq { |tag| tag[:tagid] }
      Tag.upsert_all(rows, unique_by: :tagid, record_timestamps: true)
      Success(rows.size)
    end
  end
end
