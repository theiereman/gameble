module Steam
  # Reopens the latest completed import run on its cards step, cursor 0, and
  # enqueues its first page (AD-19; story 2.8): the cards step writes every
  # game the run carried through again, so a change of Steam::PrestigeScore
  # or of the theme list (Catalog::Themes) rewrites the draft's scores and
  # genres without calling Steam. The run's card counts start again from 0
  # and its card marks (Steam::App.carded_by) are cleared, so the end of the
  # pass keeps in the draft only the cards this pass writes: a card it now
  # refuses leaves the draft. Its errors are kept. Once the last page is
  # written, the run completes again.
  #
  # Refused unless the run is the latest and completed, once its cards are
  # published (no draft season, or a season published since the run
  # finished: a run never spans two seasons), and while another run is
  # active, or once the run is abandoned (not_completed). While the run is on
  # its cards step again, the seasons page refuses to publish
  # (Steam::UnfinishedImportRun).
  #
  #   Steam::RescoreCards.new.call(import_run_id: run.id)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_latest)
  #   #    | Failure(:not_completed) | Failure(:already_published)
  #   #    | Failure(:run_in_progress)
  class RescoreCards < ApplicationOperation
    STEP = "cards".freeze

    def call(import_run_id:)
      run = transaction do
        run = step lock_run(import_run_id)
        step require_rescorable(run)
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
      return :not_completed unless run.completed?

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

    def refuse_active_run
      ImportRun.active.exists? ? Failure(:run_in_progress) : Success()
    end

    # A run started meanwhile meets the one-active-run index; the savepoint
    # keeps the transaction usable.
    def reopen(run)
      ImportRun.transaction(requires_new: true) do
        run.update!(status: :running, step: STEP, cursor: ImportRun.cursor_for(STEP), finished_at: nil,
          counts: run.counts.merge("cards_written" => 0, "cards_refused" => 0, "cards_removed" => 0))
        App.carded_by(run).update_all(carded_run_id: nil, updated_at: Time.current)
      end
      Success(run)
    rescue ActiveRecord::RecordNotUnique
      Failure(:run_in_progress)
    end
  end
end
