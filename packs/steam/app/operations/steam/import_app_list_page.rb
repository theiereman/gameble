module Steam
  # Imports the next page of the Steam app list into steam_apps (CAP-2,
  # AD-19), games only, for a running run on the app_list step.
  #
  # The page is fetched outside the transaction; then, in one transaction, the
  # apps are upserted on appid and the cursor and the apps_listed count move
  # past the page. A worker killed before the commit leaves the cursor where
  # it was: the page is fetched again and the upsert absorbs it. On the last
  # page the run completes (Steam::CompleteImport).
  #
  # A Steam failure raises Steam::WebApi::Error (key redacted), for the job to
  # retry and, once retries are spent, fail the run.
  #
  # `cursor`, when given, is the cursor the caller expects the page to start
  # from; a run that has moved on fails with cursor_moved before calling Steam.
  #
  #   Steam::ImportAppListPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportAppListPage < ApplicationOperation
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
      last_appid = run.last_appid

      page = @client.get_app_list(last_appid: last_appid, max_results: @page_size)

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_at(run, last_appid)
        step upsert_apps(run, page.apps)
        next_appid = step advance(run, page, last_appid)
        step publish(AppListPageImported.new(data: { import_run_id: run.id, last_appid: next_appid }), stream_name: ImportRun.stream_name(run.id))
        step CompleteImport.new.call(import_run: run) unless more_pages?(page, next_appid, last_appid)
        run
      end
    end

    private

    def find_run(import_run_id)
      run = ImportRun.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_on_step(run)
      run.running? && run.step == STEP ? Success(run) : Failure(:not_running)
    end

    def require_expected_cursor(run, cursor)
      cursor.nil? || run.cursor == cursor ? Success(run) : Failure(:cursor_moved)
    end

    # Another job imported this page meanwhile: nothing to do twice.
    def require_cursor_at(run, last_appid)
      run.last_appid == last_appid ? Success(run) : Failure(:cursor_moved)
    end

    def upsert_apps(run, apps)
      return Success(0) if apps.empty?

      rows = apps.map { |app| app.slice(:appid, :name, :last_modified, :price_change_number).merge(import_run_id: run.id) }
      App.upsert_all(rows, unique_by: :appid, record_timestamps: true)
      Success(rows.size)
    end

    # The cursor is the page's last_appid (or its highest appid when Steam
    # leaves it out); it never moves back.
    def advance(run, page, last_appid)
      next_appid = [ page.last_appid.to_i, *page.apps.map { |app| app[:appid] }, last_appid ].max
      run.update!(
        cursor: run.cursor.merge("last_appid" => next_appid),
        counts: run.counts.merge("apps_listed" => run.apps_listed + page.apps.size)
      )
      Success(next_appid)
    end

    # Steam says there is more, and the cursor moved: a page that does not
    # move the cursor ends the step rather than loop on itself.
    def more_pages?(page, next_appid, last_appid)
      page.have_more_results && next_appid > last_appid
    end
  end
end
