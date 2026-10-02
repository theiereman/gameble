module Steam
  # Reviews the next page of apps listed by a running run on the reviews step
  # (CAP-2, AD-19; epic 2 R3, R5): their review summaries come from
  # IStoreBrowseService/GetItems and each app gets this run's verdict
  # (Steam::ReviewPolicy): kept, too_few_reviews or unavailable.
  #
  # The page is the next PAGE_SIZE apps of this run after the cursor, in
  # appid order. Steam is called outside the transaction; then, in one
  # transaction, the page's rows are updated (never created) and the cursor
  # and the counts move past the page. A worker killed before the commit
  # leaves the cursor where it was, and the page is reviewed again. When no
  # app is left after the cursor, the step finishes (Steam::FinishImportStep)
  # without calling Steam.
  #
  # A Steam failure raises Steam::WebApi::Error (key redacted), for the job to
  # retry and, once retries are spent, fail the run.
  #
  # `cursor`, when given, is the cursor the caller expects the page to start
  # from; a run that has moved on fails with cursor_moved before the page is
  # read.
  #
  #   Steam::ImportReviewsPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportReviewsPage < ApplicationOperation
    include PageSteps

    STEP = "reviews".freeze
    PAGE_SIZE = 100
    CONTEXT = { language: "english", country_code: "US" }.freeze
    DATA_REQUEST = { include_reviews: true }.freeze

    def initialize(client: WebApi.new, page_size: PAGE_SIZE)
      super()
      @client = client
      @page_size = page_size
    end

    def call(import_run_id:, cursor: nil)
      run = step find_run(import_run_id)
      step require_on_step(run)
      step require_expected_cursor(run, cursor)
      expected_cursor = run.cursor
      last_appid = run.last_appid

      appids = page_appids(run, last_appid)
      items = appids.empty? ? {} : @client.get_items(appids: appids, context: CONTEXT, data_request: DATA_REQUEST)

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged(run, expected_cursor)
        if appids.empty?
          step FinishImportStep.new.call(import_run: run)
        else
          verdicts = appids.index_with { |appid| ReviewPolicy.verdict(items[appid]) }
          step update_apps(run, verdicts)
          kept = verdicts.values.count(&:kept?)
          step advance_page(run, last_appid: verdicts.keys.max,
            add: { "apps_reviewed" => verdicts.size, "apps_kept" => kept, "apps_excluded" => verdicts.size - kept })
          step publish_page(ReviewsPageImported, run)
        end
        run
      end
    end

    private

    # Only apps this run listed: an app it did not relist is never reviewed,
    # so never kept, by it.
    def page_appids(run, last_appid)
      App.where(import_run_id: run.id).where("appid > ?", last_appid).order(:appid).limit(@page_size).pluck(:appid)
    end

    def update_apps(run, verdicts)
      now = Time.current
      verdicts.each do |appid, verdict|
        App.where(appid: appid, import_run_id: run.id).update_all(
          review_count: verdict.review_count,
          review_percent_positive: verdict.review_percent_positive,
          reviews: verdict.reviews,
          reviewed_run_id: run.id,
          review_exclusion: verdict.exclusion,
          updated_at: now
        )
      end
      Success(verdicts.size)
    end
  end
end
