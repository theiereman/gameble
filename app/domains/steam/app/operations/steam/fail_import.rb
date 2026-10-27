module Steam
  class FailImport < ApplicationOperation
    def call(import_run_id:, error:)
      transaction do
        run = step lock_run(import_run_id)
        step require_running(run)
        run.append_errors([ error ])
        run.update!(status: :failed, finished_at: Time.current)
        step publish(ImportRunFinished.new(data: { import_run_id: run.id, status: "failed" }), stream_name: ImportRun.stream_name(run.id))
        run
      end
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_running(run)
      run.running? ? Success(run) : Failure(:not_running)
    end
  end
end
