module Steam
  class RescoreCards < ApplicationOperation
    STEP = "cards".freeze

    def call(import_run_id:)
      run = transaction do
        run = step lock_run(import_run_id)
        step require_rescorable(run)
        step refuse_awaiting_run
        step refuse_active_run
        step reopen(run)
        step publish(CardsRescoreStarted.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        run
      end

      ImportStepJob.perform_later(run.id, run.cursor)
      run
    end

    def self.refusal(run)
      return :not_latest unless LatestImportRun.call == run
      return :run_awaiting_promotion if run.ready?
      return :not_completed unless run.completed? || run.promoted?

      published = Catalog::PublishedSeason.call
      :already_published if Catalog::DraftSeason.call.nil? ||
        (published && (run.finished_at.nil? || published.published_at >= run.finished_at))
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_rescorable(run)
      code = self.class.refusal(run)
      code ? Failure(code) : Success(run)
    end

    def refuse_awaiting_run
      ImportRun.ready.exists? ? Failure(:run_awaiting_promotion) : Success()
    end

    def refuse_active_run
      ImportRun.active.exists? ? Failure(:run_in_progress) : Success()
    end

    def reopen(run)
      ImportRun.transaction(requires_new: true) do
        run.update!(status: :running, step: STEP, cursor: ImportRun.cursor_for(STEP), finished_at: nil,
          counts: run.counts.merge("rescored_from" => run.status, "cards_written" => 0, "cards_refused" => 0, "season_number" => Catalog::DraftSeasonNumber.call))
      end
      Success(run)
    # A run started meanwhile hits the one-active-run unique index.
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
