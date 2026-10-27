module Steam
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
      step require_job_cursor_current(run, cursor)
      expected_cursor = run.cursor
      last_appid = run.last_appid

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged_under_lock(run, expected_cursor)
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

    def write_cards(run, apps)
      tag_names = Tag.where(tagid: apps.flat_map { |app| Array(app.tag_ids) }.uniq).pluck(:tagid, :name).to_h
      classification = Catalog::Themes.classification
      apps.filter_map do |app|
        code = write_card(run, app, tag_names, classification)
        "appid #{app.appid}: #{code}" if code
      end
    end

    def write_card(run, app, tag_names, classification)
      mapping = CardMapping.call(app, tag_names:, classification:)
      return mapping.failure if mapping.failure?

      attributes = mapping.value!
      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        result = @upsert.call(**attributes.except(*SCORE_KEYS), theme_keys: classification.theme_keys)
        result = @stage.call(batch_token: run.token, card_id: result.value!.id, **attributes.slice(*SCORE_KEYS)) if result.success?
        raise ActiveRecord::Rollback if result.failure?
      end
      result.failure? ? result.failure : nil
    end
  end
end
