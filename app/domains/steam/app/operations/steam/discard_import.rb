module Steam
  class DiscardImport < ApplicationOperation
    def call(import_run_id:)
      transaction do
        run = step lock_run(import_run_id)
        step require_ready(run)
        step Catalog::DiscardStagedBatch.new.call(batch_token: run.token)
        restored = run.counts["rescored_from"]
        run.update!(status: restored || :abandoned, counts: run.counts.except("rescored_from"))
        step publish(ImportRunAbandoned.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_ready(run)
      run.ready? ? Success(run) : Failure(:not_ready)
    end
  end
end
