module Steam
  # Resumes a failed import run from its cursor (AD-19): the run is running
  # again on the step and cursor it failed on, and its next page is enqueued
  # once committed. Its errors are kept. Refused while another run is active,
  # for a failed run that is not the latest, and for a run that did not fail
  # (an abandoned run included: not_resumable).
  #
  # Only the latest run can become active again (here or through
  # Steam::RescoreCards), and an abandoned run never does, so
  # Steam::UnfinishedImportRun's gate, which reads the latest run that was
  # not abandoned, covers every active run.
  #
  #   Steam::ResumeImport.new.call(import_run_id: run.id)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_resumable)
  #   #    | Failure(:run_in_progress) | Failure(:not_latest)
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

    # Why `run` cannot be resumed, or nil; the run page offers the resume
    # only when nil. Leaves out the active-run check, made under the lock.
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

    # A run started meanwhile meets the one-active-run index; the savepoint
    # keeps the transaction usable.
    def reopen(run)
      ImportRun.transaction(requires_new: true) { run.update!(status: :running, finished_at: nil) }
      Success(run)
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
