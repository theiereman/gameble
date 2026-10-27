module Steam
  class ImportStepJob < ActiveJob::Base
    queue_as :import

    STEP_OPERATIONS = {
      "app_list" => "Steam::ImportAppListPage",
      "reviews" => "Steam::ImportReviewsPage",
      "tags" => "Steam::ImportTagsPage",
      "details" => "Steam::ImportDetailsPage",
      "cards" => "Steam::ImportCardsPage"
    }.freeze
    ATTEMPTS = 3

    FAIL_RUN = ->(job, error) do
      Steam::FailImport.new.call(import_run_id: job.arguments.first, error: Steam::WebApi.new.redact("#{error.class}: #{error.message}"))
    end

    retry_on StandardError, wait: :polynomially_longer, attempts: ATTEMPTS, &FAIL_RUN

    def perform(import_run_id, cursor = nil)
      run = ImportRunById.call(import_run_id)
      return unless run&.running?

      result = STEP_OPERATIONS.fetch(run.step).constantize.new.call(import_run_id: run.id, cursor: cursor)
      return unless result.success? && result.value!.running?

      self.class.perform_later(run.id, result.value!.cursor)
    end
  end
end
