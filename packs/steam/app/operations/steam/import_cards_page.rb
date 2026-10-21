module Steam
  # Stages the next page of games a running run carried through every step,
  # on the cards step: each game is mapped by
  # Steam::CardMapping, its prestige score computed by Steam::PrestigeScore,
  # its identity written in place by Catalog::UpsertCardIdentity and its
  # season scores staged, in a batch keyed by the run's token, by
  # Catalog::StageCardSeason. The draft season is not touched. No Steam call.
  #
  # The page is the next PAGE_SIZE apps ready by this run after the cursor,
  # in appid order (Steam::App.ready_by), their tag names loaded once. In
  # one transaction, each card is written in its own savepoint; then the
  # refusals are appended to the run's errors as "appid <id>: <code>", and
  # the counts (cards_written, cards_refused) and the cursor move past the
  # page, refused apps included, so they are not retried this run.
  #
  # When no app is left after the cursor, the pass is over: the step
  # finishes (Steam::FinishImportStep) and the run is ready, its batch
  # waiting for promotion (Steam::PromoteImport).
  #
  # The identity and the staging are called without `step`, the deliberate
  # exception to ApplicationOperation's rule: their own `transaction` joins
  # the page's, so a Failure would keep the rows and event they wrote before
  # refusing. Each card therefore runs in a savepoint rolled back on
  # Failure; only that card is refused (a mapping refusal, :missing_text or
  # :invalid_card). An exception rolls the whole page back, for the job to
  # retry and, once retries are spent, fail the run.
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

    SCORE_KEYS = %i[prestige_score prestige_score_version rating review_count].freeze

    def initialize(upsert: Catalog::UpsertCardIdentity.new, stage: Catalog::StageCardSeason.new, page_size: PAGE_SIZE)
      super()
      @upsert = upsert
      @stage = stage
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
          refusals = write_cards(run, apps)
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

    # Stages each app's card; returns the refusals, "appid <id>: <code>".
    def write_cards(run, apps)
      tag_names = Tag.where(tagid: apps.flat_map { |app| Array(app.tag_ids) }.uniq).pluck(:tagid, :name).to_h
      apps.filter_map do |app|
        code = write_card(run, app, tag_names)
        "appid #{app.appid}: #{code}" if code
      end
    end

    # The refusal code of the app's card, or nil when it is staged.
    def write_card(run, app, tag_names)
      mapping = CardMapping.call(app, tag_names: tag_names)
      return mapping.failure if mapping.failure?

      attributes = mapping.value!
      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        result = @upsert.call(**attributes.except(*SCORE_KEYS))
        result = @stage.call(batch_token: run.token, card_id: result.value!.id, **attributes.slice(*SCORE_KEYS)) if result.success?
        raise ActiveRecord::Rollback if result.failure?
      end
      result.failure? ? result.failure : nil
    end
  end
end
