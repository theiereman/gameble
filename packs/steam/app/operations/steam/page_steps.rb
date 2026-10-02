module Steam
  # The steps shared by the page operations of an import run (AD-3, AD-19):
  # Steam::ImportAppListPage, ImportReviewsPage, ImportTagsPage,
  # ImportDetailsPage, ImportGenresPage and ImportCardsPage. Private steps
  # only: each operation keeps its own `call`, which dry-operation wraps only
  # when the class defines it itself. The including class defines STEP, the
  # step its pages belong to.
  #
  # A page operation reads the run and checks it before the page is read
  # (from Steam, or from the database for the cards page), then, in one
  # transaction, locks the run, checks it again and writes the page; most
  # pages then advance the cursor and counts (advance_page) and publish their
  # page event (publish_page). The tags page keeps its own count update, and
  # an empty last page only finishes its step.
  module PageSteps
    private

    def find_run(import_run_id)
      run = ImportRun.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_on_step(run)
      run.running? && run.step == self.class::STEP ? Success(run) : Failure(:not_running)
    end

    # The cursor the caller expects the page to start from, checked before
    # the page is read; nil skips the check.
    def require_expected_cursor(run, cursor)
      cursor.nil? || run.cursor == cursor ? Success(run) : Failure(:cursor_moved)
    end

    # Under the lock, the run's cursor is still the one the page was read
    # from. Otherwise another job wrote this page meanwhile: nothing to do
    # twice.
    def require_cursor_unchanged(run, cursor)
      run.cursor == cursor ? Success(run) : Failure(:cursor_moved)
    end

    # Moves the cursor past the page, to `last_appid`, and adds `add`
    # ({ count name => n }) to the run's counts.
    def advance_page(run, last_appid:, add:)
      run.update!(
        cursor: run.cursor.merge("last_appid" => last_appid),
        counts: run.counts.merge(add.to_h { |name, n| [ name, run.count_of(name) + n ] })
      )
      Success(run)
    end

    # Publishes the page event `event_class` on the run's stream (AD-10).
    def publish_page(event_class, run)
      publish(event_class.new(data: { import_run_id: run.id, last_appid: run.last_appid }), stream_name: ImportRun.stream_name(run.id))
    end
  end
end
