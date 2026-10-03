module Steam
  # Imports the next page of the Steam app list into steam_apps (CAP-2,
  # AD-19), games only, for a running run on the app_list step.
  #
  # The page is fetched outside the transaction; then, in one transaction, the
  # apps are upserted on appid and the cursor and the apps_listed count move
  # past the page. A worker killed before the commit leaves the cursor where
  # it was: the page is fetched again and the upsert absorbs it. On the last
  # page the step finishes (Steam::FinishImportStep) and the run moves on to
  # the review pass.
  #
  # A malformed entry never fails the page. An appid listed twice in the
  # page is kept once, its first entry, and appended to the run's errors as
  # "appid <id>: repeated_in_page"; the entries Steam::WebApi dropped for
  # want of a valid appid are appended as one line, "app list after appid
  # <cursor>: <n> malformed_entries". apps_listed counts the unique valid
  # apps.
  #
  # A Steam failure raises Steam::WebApi::Error (key redacted), for the job to
  # retry and, once retries are spent, fail the run.
  #
  # `cursor`, when given, is the cursor the caller expects the page to start
  # from; a run that has moved on fails with cursor_moved before the page is
  # read.
  #
  #   Steam::ImportAppListPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportAppListPage < ApplicationOperation
    include PageSteps

    STEP = "app_list".freeze
    PAGE_SIZE = 10_000

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

      page = @client.get_app_list(last_appid: last_appid, max_results: @page_size)

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged(run, expected_cursor)
        apps = page.apps.uniq { |app| app[:appid] }
        errors = page_errors(page, last_appid)
        run.append_errors(errors) if errors.any?
        listed = step upsert_apps(run, apps)
        step advance(run, page, last_appid, listed)
        step publish_page(AppListPageImported, run)
        step FinishImportStep.new.call(import_run: run) unless more_pages?(page, run.last_appid, last_appid)
        run
      end
    end

    private

    def upsert_apps(run, apps)
      return Success(0) if apps.empty?

      rows = apps.map { |app| app.slice(:appid, :name, :last_modified, :price_change_number).merge(import_run_id: run.id) }
      App.upsert_all(rows, unique_by: :appid, record_timestamps: true)
      Success(rows.size)
    end

    # The page's repeated appids and malformed entries, as error lines.
    def page_errors(page, last_appid)
      repeated = page.apps.map { |app| app[:appid] }.tally.select { |_, count| count > 1 }.keys
      errors = repeated.map { |appid| "appid #{appid}: repeated_in_page" }
      errors << "app list after appid #{last_appid}: #{page.malformed} malformed_entries" if page.malformed.positive?
      errors
    end

    # The cursor is the page's last_appid (or its highest appid when Steam
    # leaves it out); it never moves back.
    def advance(run, page, last_appid, listed)
      next_appid = [ page.last_appid.to_i, *page.apps.map { |app| app[:appid] }, last_appid ].max
      advance_page(run, last_appid: next_appid, add: { "apps_listed" => listed })
    end

    # Steam says there is more, and the cursor moved: a page that does not
    # move the cursor ends the step rather than loop on itself.
    def more_pages?(page, next_appid, last_appid)
      page.have_more_results && next_appid > last_appid
    end
  end
end
