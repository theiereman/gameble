module Steam
  # Starts an import run (CAP-2, AD-19): a running run on the first step,
  # with an empty cursor, then enqueues its first page on the import queue
  # once the run is committed. One active run at a time: the database refuses
  # a second, so two administrators starting at once get one run.
  #
  #   Steam::StartImport.new.call
  #   # => Success(run) | Failure(:run_in_progress)
  class StartImport < ApplicationOperation
    def call
      run = transaction do
        step refuse_active_run
        run = step create_run
        step publish(ImportRunStarted.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end

      ImportStepJob.perform_later(run.id, run.cursor)
      run
    end

    private

    def refuse_active_run
      ImportRun.active.exists? ? Failure(:run_in_progress) : Success()
    end

    # A run started by someone else between the check and the insert meets
    # the one-active-run index; the savepoint keeps the transaction usable.
    def create_run
      run = ImportRun.transaction(requires_new: true) do
        ImportRun.create!(
          status: :running,
          step: ImportRun::STEPS.first,
          cursor: { "last_appid" => 0 },
          counts: { "apps_listed" => 0 },
          started_at: Time.current
        )
      end
      Success(run)
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
