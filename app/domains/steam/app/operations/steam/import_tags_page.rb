module Steam
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
      step require_job_cursor_current(run, cursor)
      expected_cursor = run.cursor

      tags = @client.get_tag_list(language: LANGUAGE)

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged_under_lock(run, expected_cursor)
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
