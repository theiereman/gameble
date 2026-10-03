module Steam
  # Details the next page of games kept by a running run on the details step
  # (CAP-2, AD-19; epic 2 R3, R4, R5): their names, short descriptions,
  # publishers, release date, tags, store path and library image come from
  # IStoreBrowseService/GetItems, asked once in English and once in French,
  # and each app gets this run's verdict (Steam::DetailsPolicy): NULL when it
  # can become a card, otherwise why not.
  #
  # The page is the next PAGE_SIZE apps kept by this run after the cursor, in
  # appid order (Steam::App.kept_by). Steam is called outside the
  # transaction; then, in one transaction, the page's rows are updated (never
  # created) and the cursor and the counts move past the page. When no app is
  # left after the cursor, the step finishes (Steam::FinishImportStep) without
  # calling Steam and hands over to the cards (Steam::ImportCardsPage).
  #
  # A Steam failure raises Steam::WebApi::Error (key redacted), for the job to
  # retry and, once retries are spent, fail the run.
  #
  # `cursor`, when given, is the cursor the caller expects the page to start
  # from; a run that has moved on fails with cursor_moved before the page is
  # read.
  #
  #   Steam::ImportDetailsPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportDetailsPage < ApplicationOperation
    include PageSteps

    STEP = "details".freeze
    PAGE_SIZE = 100
    ENGLISH = { language: "english", country_code: "US" }.freeze
    FRENCH = { language: "french", country_code: "US" }.freeze
    DATA_REQUEST = { include_basic_info: true, include_assets: true, include_release: true, include_tag_count: 20 }.freeze

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
      unless appids.empty?
        english = @client.get_items(appids: appids, context: ENGLISH, data_request: DATA_REQUEST)
        french = @client.get_items(appids: appids, context: FRENCH, data_request: DATA_REQUEST)
      end

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged(run, expected_cursor)
        if appids.empty?
          step FinishImportStep.new.call(import_run: run)
        else
          verdicts = appids.index_with { |appid| DetailsPolicy.verdict(appid, english[appid], french[appid]) }
          step update_apps(run, verdicts)
          excluded = verdicts.values.count { |verdict| !verdict.kept? }
          step advance_page(run, last_appid: verdicts.keys.max,
            add: { "apps_detailed" => verdicts.size, "apps_excluded_details" => excluded })
          step publish_page(DetailsPageImported, run)
        end
        run
      end
    end

    private

    def page_appids(run, last_appid)
      App.kept_by(run).where("appid > ?", last_appid).order(:appid).limit(@page_size).pluck(:appid)
    end

    def update_apps(run, verdicts)
      now = Time.current
      verdicts.each do |appid, verdict|
        App.kept_by(run).where(appid: appid).update_all(verdict.attributes.merge(details_run_id: run.id, updated_at: now))
      end
      Success(verdicts.size)
    end
  end
end
