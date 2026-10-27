module Steam
  # The latest import run that was not abandoned, when it has not completed
  # or been promoted (pending, running, failed or ready), or nil.
  # The latest run, when failed, can still be resumed and stage its
  # remaining cards, and a ready run waits for promotion, so the back-office
  # refuses to publish a season until the run is promoted or abandoned: a
  # run never spans two seasons. An abandoned run (Steam::AbandonImport,
  # Steam::DiscardImport) is skipped and the run before it decides. Only the
  # latest run can become active again (Steam::ResumeImport,
  # Steam::RescoreCards), so reading the latest runs covers every active one.
  module UnfinishedImportRun
    def self.call
      run = ImportRun.where.not(status: :abandoned).latest_first.first
      run unless run.nil? || run.completed? || run.promoted?
    end
  end
end
