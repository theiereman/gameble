module Steam
  class ResumeImport < ApplicationOperation
    def call(import_run_id:)
      run = transaction do
        run = step lock_run(import_run_id)
        step require_failed(run)
        step refuse_active_run
        step require_latest(run)
        step reopen(run)
        step publish(ImportRunStarted.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end

      ImportStepJob.perform_later(run.id, run.cursor)
      run
    end

    def self.refusal(run)
      return :not_resumable unless run.failed?

      :not_latest unless LatestImportRun.call == run
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_failed(run)
      run.failed? ? Success(run) : Failure(:not_resumable)
    end

    def refuse_active_run
      ImportRun.active.exists? ? Failure(:run_in_progress) : Success()
    end

    def require_latest(run)
      LatestImportRun.call == run ? Success(run) : Failure(:not_latest)
    end

    def reopen(run)
      ImportRun.transaction(requires_new: true) { run.update!(status: :running, finished_at: nil) }
      Success(run)
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
