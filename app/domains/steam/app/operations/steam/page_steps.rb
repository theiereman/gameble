module Steam
  module PageSteps
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
      run.running? && run.step == self.class::STEP ? Success(run) : Failure(:not_running)
    end

    def require_job_cursor_current(run, cursor)
      cursor.nil? || run.cursor == cursor ? Success(run) : Failure(:cursor_moved)
    end

    def require_cursor_unchanged_under_lock(run, cursor)
      run.cursor == cursor ? Success(run) : Failure(:cursor_moved)
    end

    def advance_page(run, last_appid:, add:)
      run.update!(
        cursor: run.cursor.merge("last_appid" => last_appid),
        counts: run.counts.merge(add.to_h { |name, n| [ name, run.count_of(name) + n ] })
      )
      Success(run)
    end

    def publish_page(event_class, run)
      publish(event_class.new(data: { import_run_id: run.id, last_appid: run.last_appid }), stream_name: ImportRun.stream_name(run.id))
    end
  end
end
