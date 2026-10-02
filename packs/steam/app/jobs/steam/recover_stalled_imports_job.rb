module Steam
  # Enqueues the next page of every stalled import run (AD-19), on a recurring
  # schedule (config/recurring.yml). A run moves its updated_at with every page,
  # so a running run that has not moved for Steam::StalledImportRuns::STALL_AFTER
  # lost its page job, as when the import worker is killed outright.
  #
  # The page job carries the run's committed cursor. Every job enqueued for
  # that cursor (one per recovery while the worker is down, or the original
  # that was not lost after all) but the first finds the cursor moved and
  # stops (Steam::ImportStepJob), so the run keeps one chain of page jobs.
  class RecoverStalledImportsJob < ActiveJob::Base
    queue_as :default

    def perform
      StalledImportRuns.call.each { |run| ImportStepJob.perform_later(run.id, run.cursor) }
    end
  end
end
