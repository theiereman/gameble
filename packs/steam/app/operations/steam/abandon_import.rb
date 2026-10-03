module Steam
  # Abandons the latest failed import run (AD-19; story 2.11): an
  # administrator gives up on a run that keeps failing rather than resume it.
  # The run becomes abandoned, its finished_at and errors kept; an abandoned
  # run is finished for good: it blocks no new run, is never resumed or
  # rescored, and Steam::UnfinishedImportRun skips it when deciding whether
  # a season can be published.
  #
  # Refused unless the run failed (not_abandonable) and is the latest
  # (not_latest), and once it wrote at least one card in its current pass,
  # on the cards step (cards_written): those cards replaced the previous
  # pass's in the draft and cannot be restored, so the run is resumed, or a
  # new run is started, whose completion prunes the draft. A pass whose
  # every card was refused never touched the draft and can be abandoned.
  #
  #   Steam::AbandonImport.new.call(import_run_id: run.id)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_abandonable)
  #   #    | Failure(:not_latest) | Failure(:cards_written)
  class AbandonImport < ApplicationOperation
    def call(import_run_id:)
      transaction do
        run = step lock_run(import_run_id)
        step require_abandonable(run)
        run.update!(status: :abandoned)
        step publish(ImportRunAbandoned.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end
    end

    # Why `run` cannot be abandoned, or nil; the run page offers the abandon
    # only when nil.
    def self.refusal(run)
      return :not_abandonable unless run.failed?
      return :not_latest unless LatestImportRun.call == run

      :cards_written if run.step == ImportCardsPage::STEP && run.cards_written.positive?
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
