module Steam
  class StartImport < ApplicationOperation
    def call
      run = transaction do
        step refuse_awaiting_run
        step refuse_active_run
        run = step create_run
        step publish(ImportRunStarted.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end

      ImportStepJob.perform_later(run.id, run.cursor)
      run
    end

    private

    def refuse_awaiting_run
      ImportRun.ready.exists? ? Failure(:run_awaiting_promotion) : Success()
    end

    def refuse_active_run
      ImportRun.active.exists? ? Failure(:run_in_progress) : Success()
    end

    def create_run
      run = ImportRun.transaction(requires_new: true) do
        ImportRun.create!(
          status: :running,
          step: ImportRun::STEPS.first,
          cursor: ImportRun.cursor_for(ImportRun::STEPS.first),
          counts: { "apps_listed" => 0, "season_number" => Catalog::DraftSeasonNumber.call },
          started_at: Time.current
        )
      end
      Success(run)
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
