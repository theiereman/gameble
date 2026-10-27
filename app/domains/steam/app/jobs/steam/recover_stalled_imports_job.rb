module Steam
  class RecoverStalledImportsJob < ActiveJob::Base
    queue_as :default

    def perform
      StalledImportRuns.call.each { |run| ImportStepJob.perform_later(run.id, run.cursor) }
    end
  end
end
