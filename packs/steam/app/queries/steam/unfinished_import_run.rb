module Steam
  # The latest import run when it has not completed (pending, running or
  # failed), or nil (AD-3, AD-19). The latest run, when failed, can still be
  # resumed and write its remaining cards, so the back-office refuses to
  # publish a season until the latest run completes: a run never spans two
  # seasons. Only the latest run can become active again (Steam::ResumeImport,
  # Steam::RescoreCards), so reading the latest run covers every active one.
  module UnfinishedImportRun
    def self.call
      run = ImportRun.latest_first.first
      run unless run.nil? || run.completed?
    end
  end
end
