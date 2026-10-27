module Steam
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
      step require_job_cursor_current(run, cursor)
      expected_cursor = run.cursor
      last_appid = run.last_appid

      page = @client.get_app_list(last_appid: last_appid, max_results: @page_size)

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged_under_lock(run, expected_cursor)
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

    def page_errors(page, last_appid)
      repeated = page.apps.map { |app| app[:appid] }.tally.select { |_, count| count > 1 }.keys
      errors = repeated.map { |appid| "appid #{appid}: repeated_in_page" }
      errors << "app list after appid #{last_appid}: #{page.malformed} malformed_entries" if page.malformed.positive?
      errors
    end

    def advance(run, page, last_appid, listed)
      next_appid = [ page.last_appid.to_i, *page.apps.map { |app| app[:appid] }, last_appid ].max
      advance_page(run, last_appid: next_appid, add: { "apps_listed" => listed })
    end

    def more_pages?(page, next_appid, last_appid)
      page.have_more_results && next_appid > last_appid
    end
  end
end
