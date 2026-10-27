module Steam
  class ImportDetailsPage < ApplicationOperation
    include PageSteps

    STEP = "details".freeze
    PAGE_SIZE = 100
    ENGLISH = { language: "english", country_code: "US" }.freeze
    FRENCH = { language: "french", country_code: "US" }.freeze
    DATA_REQUEST = { include_basic_info: true, include_assets: true, include_release: true, include_tag_count: 20 }.freeze

    def initialize(client: WebApi.new, page_size: PAGE_SIZE)
      super()
      @client = client
      @page_size = page_size
    end

    def call(import_run_id:, cursor: nil)
      run = step find_run(import_run_id)
      step require_on_step(run)
      step require_job_cursor_current(run, cursor)
      expected_cursor = run.cursor
      last_appid = run.last_appid

      appids = page_appids(run, last_appid)
      unless appids.empty?
        english = @client.get_items(appids: appids, context: ENGLISH, data_request: DATA_REQUEST)
        french = @client.get_items(appids: appids, context: FRENCH, data_request: DATA_REQUEST)
      end

      transaction do
        run = step lock_run(import_run_id)
        step require_on_step(run)
        step require_cursor_unchanged_under_lock(run, expected_cursor)
        if appids.empty?
          step FinishImportStep.new.call(import_run: run)
        else
          verdicts = appids.index_with { |appid| DetailsPolicy.verdict(appid, english[appid], french[appid]) }
          step update_apps(run, verdicts)
          excluded = verdicts.values.count { |verdict| !verdict.kept? }
          step advance_page(run, last_appid: verdicts.keys.max,
            add: { "apps_detailed" => verdicts.size, "apps_excluded_details" => excluded })
          step publish_page(DetailsPageImported, run)
        end
        run
      end
    end

    private

    def page_appids(run, last_appid)
      App.kept_by(run).where("appid > ?", last_appid).order(:appid).limit(@page_size).pluck(:appid)
    end

    def update_apps(run, verdicts)
      now = Time.current
      verdicts.each do |appid, verdict|
        App.kept_by(run).where(appid: appid).update_all(verdict.attributes.merge(details_run_id: run.id, updated_at: now))
      end
      Success(verdicts.size)
    end
  end
end
