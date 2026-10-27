module Steam
  # Reopens the latest completed or promoted import run on its cards step,
  # cursor 0, and enqueues its first page: the cards step stages
  # every game the run carried through again, so a change of
  # Steam::PrestigeScore or of the classification of tags into themes
  # (Catalog::Themes) gives a new
  # batch to review and promote like an import, without calling Steam and
  # without editing the draft. The run's card counts start again from 0 and
  # it begins on the current draft season (season_number). Its errors are
  # kept. Once the last page is staged, the run is ready again.
  #
  # Refused unless the run is the latest and completed or promoted, once its
  # cards are published (no draft season, or a season published since the
  # run finished: a run never spans two seasons), while a run waits for
  # promotion (run_awaiting_promotion) or another run is active, and once
  # the run is abandoned (not_completed). While the run is on its cards step
  # again, the seasons page refuses to publish (Steam::UnfinishedImportRun).
  #
  #   Steam::RescoreCards.new.call(import_run_id: run.id)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_latest)
  #   #    | Failure(:not_completed) | Failure(:already_published)
  #   #    | Failure(:run_in_progress) | Failure(:run_awaiting_promotion)
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

    # Why `run` cannot be rescored, or nil; the run page offers the rescore
    # only when nil. Leaves out the active-run check, made under the lock.
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

    # A run started meanwhile meets the one-active-run index; the savepoint
    # keeps the transaction usable.
    def reopen(run)
      ImportRun.transaction(requires_new: true) do
        run.update!(status: :running, step: STEP, cursor: ImportRun.cursor_for(STEP), finished_at: nil,
          counts: run.counts.merge("rescored_from" => run.status, "cards_written" => 0, "cards_refused" => 0, "season_number" => Catalog::DraftSeasonNumber.call))
      end
      Success(run)
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
