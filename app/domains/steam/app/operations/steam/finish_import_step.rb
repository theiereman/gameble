module Steam
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
