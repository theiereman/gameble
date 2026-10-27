module Steam
  class AbandonImport < ApplicationOperation
    def call(import_run_id:)
      transaction do
        run = step lock_run(import_run_id)
        step require_abandonable(run)
        step Catalog::DiscardStagedBatch.new.call(batch_token: run.token)
        run.update!(status: :abandoned)
        step publish(ImportRunAbandoned.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end
    end

    def self.refusal(run)
      return :not_abandonable unless run.failed?

      :not_latest unless ImportRun.where.not(status: :abandoned).latest_first.first == run
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_abandonable(run)
      code = self.class.refusal(run)
      code ? Failure(code) : Success(run)
    end
  end
end
