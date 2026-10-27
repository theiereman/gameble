module Steam
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
