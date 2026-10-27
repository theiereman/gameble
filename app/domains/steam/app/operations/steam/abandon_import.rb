module Steam
  # Abandons the latest failed import run (AD-19; story 2.11): an
  # administrator gives up on a run that keeps failing rather than resume it.
  # The run becomes abandoned, its finished_at and errors kept; an abandoned
  # run is finished for good: it blocks no new run, is never resumed or
  # rescored, and Steam::UnfinishedImportRun skips it when deciding whether
  # a season can be published.
  #
  # "Latest" leaves abandoned runs out, as the publish gate does: once the
  # latest run is abandoned, a failed run before it, which now decides
  # whether a season can be published, can be abandoned in turn.
  #
  # The run's staged cards (Catalog::DiscardStagedBatch) are deleted with
  # it; the draft season was never touched by the run, so it is left as it
  # stood.
  #
  # Refused unless the run failed (not_abandonable) and is the latest
  # (not_latest).
  #
  #   Steam::AbandonImport.new.call(import_run_id: run.id)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_abandonable)
  #   #    | Failure(:not_latest)
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

    # Why `run` cannot be abandoned, or nil; the run page offers the abandon
    # only when nil.
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
