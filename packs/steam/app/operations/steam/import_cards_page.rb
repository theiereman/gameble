module Steam
  # Writes the next page of games a running run carried through every step
  # into the draft season as cards (CAP-2, CAP-3, AD-4, AD-19; epic 2 R4,
  # R5), on the cards step: each game is mapped by Steam::CardMapping, its
  # prestige score computed by Steam::PrestigeScore, and the card written by
  # Catalog::UpsertDraftCard. No Steam call.
  #
  # The page is the next PAGE_SIZE apps ready by this run after the cursor,
  # in appid order (Steam::App.ready_by), their tag names loaded once. In
  # one transaction, each card is written in its own savepoint; then the
  # refusals are appended to the run's errors as "appid <id>: <code>", and
  # the counts (cards_written, cards_refused) and the cursor move past the
  # page, refused apps included, so they are not retried this run. When no
  # app is left after the cursor, the step finishes
  # (Steam::FinishImportStep); after this last step, the run completes.
  #
  # The upsert is called without `step`, the deliberate exception to
  # ApplicationOperation's rule: its own `transaction` joins the page's, so
  # a Failure would keep the rows and event it wrote before refusing. Each
  # call therefore runs in a savepoint rolled back on Failure; only that card
  # is refused (a mapping refusal, :missing_text or :invalid_card). An
  # exception rolls the whole page back, for the job to retry and, once
  # retries are spent, fail the run.
  #
  # The upsert locks the draft season FOR SHARE, and the lock is held until
  # the page commits: a season publish waits up to one page.
  #
  # `cursor`, when given, is the cursor the caller expects the page to start
  # from; a run that has moved on fails with cursor_moved before the page is
  # read.
  #
  #   Steam::ImportCardsPage.new.call(import_run_id: run.id, cursor: run.cursor)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running) | Failure(:cursor_moved)
  class ImportCardsPage < ApplicationOperation
    include PageSteps

    STEP = "cards".freeze
    PAGE_SIZE = 100

    def initialize(upsert: Catalog::UpsertDraftCard.new, page_size: PAGE_SIZE)
      super()
      @upsert = upsert
      @page_size = page_size
    end

    def call(import_run_id:, cursor: nil)
      run = step find_run(import_run_id)
      step require_on_step(run)
      step require_expected_cursor(run, cursor)
      expected_cursor = run.cursor
      last_appid = run.last_appid

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged(run, expected_cursor)
        apps = page_apps(run, last_appid)
        if apps.empty?
          step FinishImportStep.new.call(import_run: run)
        else
          refusals = write_cards(apps)
          run.append_errors(refusals) if refusals.any?
          step advance_page(run, last_appid: apps.map(&:appid).max,
            add: { "cards_written" => apps.size - refusals.size, "cards_refused" => refusals.size })
          step publish_page(CardsPageImported, run)
        end
        run
      end
    end

    private

    def page_apps(run, last_appid)
      App.ready_by(run).where("appid > ?", last_appid).order(:appid).limit(@page_size).to_a
    end

    # Writes each app's card; returns the refusals, "appid <id>: <code>".
    def write_cards(apps)
      tag_names = Tag.where(tagid: apps.flat_map { |app| Array(app.tag_ids) }.uniq).pluck(:tagid, :name).to_h
      apps.filter_map do |app|
        code = write_card(app, tag_names)
        "appid #{app.appid}: #{code}" if code
      end
    end

    # The refusal code of the app's card, or nil when it is written.
    def write_card(app, tag_names)
      mapping = CardMapping.call(app, tag_names: tag_names)
      return mapping.failure if mapping.failure?

      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        result = @upsert.call(**mapping.value!)
        raise ActiveRecord::Rollback if result.failure?
      end
      result.failure? ? result.failure : nil
    end
  end
end
