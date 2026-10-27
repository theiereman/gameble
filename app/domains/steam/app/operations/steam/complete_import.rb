module Steam
  # Completes an import run after its last step: the run is ready,
  # its staged cards waiting for promotion. Called by the operation that
  # imported the last page, inside its transaction, with the run it locked.
  #
  #   step Steam::CompleteImport.new.call(import_run: run)
  #   # => Success(run) | Failure(:not_running)
  class CompleteImport < ApplicationOperation
    def call(import_run:)
      transaction do
        step require_running(import_run)
        import_run.update!(status: :ready, finished_at: Time.current)
        step publish(ImportRunFinished.new(data: { import_run_id: import_run.id, status: "ready" }), stream_name: ImportRun.stream_name(import_run.id))
        import_run
      end
    end

    private

    def require_running(run)
      run.running? ? Success(run) : Failure(:not_running)
    end
  end
end
