module Steam
  # Gives the next page of games detailed by a running run on the genres step
  # their genres and credit (CAP-2, AD-19; epic 2 R4, R7), from the store's
  # appdetails, one game per call, spaced under the store rate limit by
  # Steam::StoreApi. Each app gets this run's verdict (Steam::GenresPolicy).
  #
  # The page is the next PAGE_SIZE apps detailed by this run after the
  # cursor, in appid order (Steam::App.detailed_by). The store is called
  # outside the transaction; then, in one transaction, the page's rows are
  # updated (never created) and the cursor and the counts move past the page.
  # When no app is left after the cursor, the step finishes
  # (Steam::FinishImportStep) without calling Steam; after this last step, the
  # run completes.
  #
  # A store failure raises Steam::StoreApi::Error; a rate limit that outlasts
  # the client's retries raises Steam::StoreApi::RateLimited, which the job
  # retries minutes later.
  #
  #   Steam::ImportGenresPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportGenresPage < ApplicationOperation
    STEP = "genres".freeze
    PAGE_SIZE = 5

    def initialize(client: StoreApi.new, page_size: PAGE_SIZE)
      super()
      @client = client
      @page_size = page_size
    end

    def call(import_run_id:, cursor: nil)
      run = step find_run(import_run_id)
      step require_on_step(run)
      step require_expected_cursor(run, cursor)
      last_appid = run.last_appid

      appids = page_appids(run, last_appid)
      entries = appids.index_with { |appid| @client.app_details(appid) }

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_at(run, last_appid)
        if appids.empty?
          step FinishImportStep.new.call(import_run: run)
        else
          verdicts = entries.to_h { |appid, entry| [ appid, GenresPolicy.verdict(appid, entry) ] }
          step update_apps(run, verdicts)
          step advance(run, verdicts)
          step publish(GenresPageImported.new(data: { import_run_id: run.id, last_appid: run.last_appid }), stream_name: ImportRun.stream_name(run.id))
        end
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

    # Another job gave this page its genres meanwhile: nothing to do twice.
    def require_cursor_at(run, last_appid)
      run.last_appid == last_appid ? Success(run) : Failure(:cursor_moved)
    end

    def page_appids(run, last_appid)
      App.detailed_by(run).where("appid > ?", last_appid).order(:appid).limit(@page_size).pluck(:appid)
    end

    def update_apps(run, verdicts)
      now = Time.current
      verdicts.each do |appid, verdict|
        App.detailed_by(run).where(appid: appid).update_all(verdict.attributes.merge(genres_run_id: run.id, updated_at: now))
      end
      Success(verdicts.size)
    end

    def advance(run, verdicts)
      excluded = verdicts.values.count { |verdict| !verdict.kept? }
      run.update!(
        cursor: run.cursor.merge("last_appid" => verdicts.keys.max),
        counts: run.counts.merge(
          "apps_genred" => run.apps_genred + verdicts.size,
          "apps_excluded_genres" => run.apps_excluded_genres + excluded
        )
      )
      Success(run)
    end
  end
end
