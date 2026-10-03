module Steam
  # The latest import run that was not abandoned, when it has not completed
  # (pending, running or failed), or nil (AD-3, AD-19). The latest run, when
  # failed, can still be resumed and write its remaining cards, so the
  # back-office refuses to publish a season until a run completes: a run
  # never spans two seasons. An abandoned run (Steam::AbandonImport) wrote
  # no card in its last pass, so it is skipped and the run before it
  # decides: a failed run before it can be abandoned in turn, unless it
  # wrote cards in its pass, which keeps publishing blocked until a new run
  # completes. Only the latest run can become active again
  # (Steam::ResumeImport, Steam::RescoreCards), so reading the latest runs
  # covers every active one.
  module UnfinishedImportRun
    def self.call
      run = ImportRun.where.not(status: :abandoned).latest_first.first
      run unless run.nil? || run.completed?
    end
  end
end
