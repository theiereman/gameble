module Steam
  # Advances an import run by one page of its current step (AD-19), on the
  # import queue, served by its own worker with one thread (config/queue_import.yml).
  #
  # A page is one job: the step's operation imports the page and commits the
  # cursor with it, then the job enqueues the next page while the run is still
  # running; when a page finishes its step, the next step's first page is
  # enqueued the same way. Each job carries the cursor its page starts from: a job whose
  # cursor is no longer the run's (a duplicate, an old retry) stops without
  # calling Steam, so a run has one chain of page jobs. A worker stopped
  # gracefully hands its job back, which runs again from the committed
  # cursor; a worker killed outright loses it, and
  # Steam::RecoverStalledImportsJob enqueues the page again.
  #
  # Any error is retried; once the attempts are spent, the run fails with the
  # error (key redacted) and can be resumed from its cursor.
  class ImportStepJob < ActiveJob::Base
    queue_as :import

    STEP_OPERATIONS = { "app_list" => "Steam::ImportAppListPage", "reviews" => "Steam::ImportReviewsPage" }.freeze
    ATTEMPTS = 3

    retry_on StandardError, wait: :polynomially_longer, attempts: ATTEMPTS do |job, error|
      Steam::FailImport.new.call(import_run_id: job.arguments.first, error: Steam::WebApi.new.redact("#{error.class}: #{error.message}"))
    end

    # `cursor` is the run's cursor when the job was enqueued; nil skips the check.
    def perform(import_run_id, cursor = nil)
      run = ImportRunById.call(import_run_id)
      return unless run&.running?

      result = STEP_OPERATIONS.fetch(run.step).constantize.new.call(import_run_id: run.id, cursor: cursor)
      return unless result.success? && result.value!.running?

      self.class.perform_later(run.id, result.value!.cursor)
    end
  end
end
