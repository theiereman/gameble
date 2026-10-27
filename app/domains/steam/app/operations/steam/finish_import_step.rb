module Steam
  # Finishes the current step of an import run (AD-19). Called by the
  # operation that found its step done, inside its transaction, with the run
  # it locked. The run moves to the next step, its cursor at the start of
  # that step; after the last step it completes (Steam::CompleteImport).
  #
  # The cursor names its step, so a job still holding a cursor of the
  # finished step no longer matches the run's and stops (cursor_moved).
  #
  #   step Steam::FinishImportStep.new.call(import_run: run)
  #   # => Success(run) | Failure(:not_running)
  class FinishImportStep < ApplicationOperation
    def call(import_run:)
      transaction do
        step require_running(import_run)
        finished = import_run.step
        next_step = ImportRun.next_step(finished)
        import_run.update!(step: next_step, cursor: ImportRun.cursor_for(next_step)) if next_step
        step publish(ImportStepFinished.new(data: { import_run_id: import_run.id, step: finished }), stream_name: ImportRun.stream_name(import_run.id))
        step CompleteImport.new.call(import_run: import_run) unless next_step
        import_run
      end
    end

    private

    def require_running(run)
      run.running? ? Success(run) : Failure(:not_running)
    end
  end
end
