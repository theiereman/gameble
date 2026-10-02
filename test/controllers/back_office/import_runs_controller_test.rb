require "test_helper"

module BackOffice
  # The Steam import page of the back-office (AD-19), administrators only.
  class ImportRunsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      OmniAuth.config.test_mode = true
    end

    teardown do
      OmniAuth.config.mock_auth.delete(:steam)
      OmniAuth.config.test_mode = false
    end

    def sign_in(player)
      OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
      post "/auth/steam", params: { origin: "/fr" }
      follow_redirect!
      assert_equal player.id, session[:player_id]
    end

    def running_run(apps_listed: 0)
      Steam::ImportRun.create!(status: :running, step: "app_list", cursor: { "last_appid" => 42 }, counts: { "apps_listed" => apps_listed }, started_at: 1.minute.ago)
    end

    def failed_run
      Steam::ImportRun.create!(status: :failed, step: "app_list", cursor: { "last_appid" => 42 }, counts: { "apps_listed" => 7 }, started_at: 1.hour.ago, finished_at: 1.minute.ago,
        error_messages: [ { "at" => 1.minute.ago.utc.iso8601, "message" => "Steam::WebApi::Error: the server responded with status 503 for GET https://api.steampowered.com/?key=[FILTERED]" } ])
    end

    test "an administrator sees the runs, the latest first" do
      sign_in(accounts_players(:administrator))
      old = Steam::ImportRun.create!(status: :completed, step: "app_list", counts: { "apps_listed" => 1234 }, created_at: 2.days.ago)
      recent = failed_run

      get back_office_import_runs_path(locale: :fr)

      assert_response :success
      assert_select "h1", "L'import Steam"
      assert_select "form[action='/fr/back-office/import-runs'][method=post] button", "Lancer un import"
      assert_select "table.ledger tbody tr", 2
      assert_select "table.ledger tbody tr:first-child a[href='/fr/back-office/import-runs/#{recent.token}']"
      assert_select "table.ledger tbody tr:last-child td", /Terminé/
      assert_select "table.ledger tbody tr:last-child a[href='/fr/back-office/import-runs/#{old.token}']"
      assert_no_match(/import-runs\/#{old.id}\b/, response.body)
    end

    test "an administrator with no run sees the empty ledger" do
      sign_in(accounts_players(:administrator))

      get back_office_import_runs_path(locale: :en)

      assert_select "table", false
      assert_select ".text-plate", /No import has run yet/
    end

    test "an administrator starts an import and lands on its page, which shows the app_list step and polls" do
      sign_in(accounts_players(:administrator))

      assert_enqueued_with(job: Steam::ImportStepJob, queue: "import") do
        post back_office_import_runs_path(locale: :fr)
      end

      run = Steam::ImportRun.sole
      assert_predicate run, :running?
      assert_redirected_to back_office_import_run_path(run, locale: :fr)
      follow_redirect!
      assert_equal I18n.t("back_office.import_runs.create.started", locale: :fr), flash[:notice]
      assert_select "turbo-frame#import_run [data-controller=poller][data-poller-url-value='/fr/back-office/import-runs/#{run.token}']"
      assert_select "[data-import-run-step=app_list]"
      assert_select "[data-import-run-apps-listed='0']", "0"
      assert_select "[data-import-run-status=running]", "En cours"
    end

    test "starting a second import is refused with run_in_progress" do
      sign_in(accounts_players(:administrator))
      running_run

      assert_no_enqueued_jobs { post back_office_import_runs_path(locale: :en) }

      assert_redirected_to back_office_import_runs_path(locale: :en)
      assert_equal I18n.t("errors.steam.run_in_progress", locale: :en), flash[:alert]
      assert_equal 1, Steam::ImportRun.count
    end

    test "a running run's page shows its growing count" do
      sign_in(accounts_players(:administrator))
      run = running_run(apps_listed: 12_345)

      get back_office_import_run_path(run, locale: :en)

      assert_response :success
      assert_select "[data-import-run-apps-listed='12345']", "12,345"
      assert_select "[data-controller=poller]"
    end

    test "a failed run's page shows its errors and offers to resume, without polling" do
      sign_in(accounts_players(:administrator))
      run = failed_run

      get back_office_import_run_path(run, locale: :fr)

      assert_select "[data-controller=poller]", false
      assert_select "[data-import-run-status=failed]", "Interrompu"
      assert_select ".ledger-errors li", /status 503/
      assert_select "form[action='/fr/back-office/import-runs/#{run.token}/resume'] button", "Reprendre là où il s'est arrêté"
    end

    test "a completed run's page neither polls nor offers to resume" do
      sign_in(accounts_players(:administrator))
      run = Steam::ImportRun.create!(status: :completed, step: "app_list", finished_at: Time.current)

      get back_office_import_run_path(run, locale: :en)

      assert_select "[data-controller=poller]", false
      assert_select "form[action$='/resume']", false
    end

    test "an unknown run is not found" do
      sign_in(accounts_players(:administrator))

      get back_office_import_run_path("nope", locale: :en)

      assert_response :not_found
    end

    test "an administrator resumes a failed run" do
      sign_in(accounts_players(:administrator))
      run = failed_run

      assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, run.cursor ], queue: "import") do
        post resume_back_office_import_run_path(run, locale: :en)
      end

      assert_redirected_to back_office_import_run_path(run, locale: :en)
      assert_equal I18n.t("back_office.import_runs.resume.resumed", locale: :en), flash[:notice]
      assert_predicate run.reload, :running?
    end

    test "resuming a run that has not failed is refused with not_resumable" do
      sign_in(accounts_players(:administrator))
      run = running_run

      post resume_back_office_import_run_path(run, locale: :en)

      assert_redirected_to back_office_import_run_path(run, locale: :en)
      assert_equal I18n.t("errors.steam.not_resumable", locale: :en), flash[:alert]
    end

    test "the back-office links to the import for an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :fr)

      assert_select "main a.button--secondary[href='/fr/back-office/import-runs']", "L'import Steam"

      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :fr)

      assert_select "a[href$='/import-runs']", false
    end

    def each_request(run)
      yield :get, back_office_import_runs_path(locale: :fr)
      yield :get, back_office_import_run_path(run, locale: :fr)
      yield :post, back_office_import_runs_path(locale: :fr)
      yield :post, resume_back_office_import_run_path(run, locale: :fr)
    end

    [ :player, :moderator ].each do |role|
      test "a #{role} is refused every import action with 403" do
        run = failed_run
        sign_in(accounts_players(role))

        each_request(run) do |verb, path|
          assert_no_enqueued_jobs { public_send(verb, path) }

          assert_response :forbidden, "#{verb} #{path}"
          assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
        end
        assert_predicate run.reload, :failed?
        assert_equal 1, Steam::ImportRun.count
      end
    end

    test "a visitor is sent to the attic and asked to sign in for every import action" do
      run = failed_run

      each_request(run) do |verb, path|
        public_send(verb, path)

        assert_redirected_to home_path(locale: :fr), "#{verb} #{path}"
        assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]
      end
      assert_predicate run.reload, :failed?
      assert_equal 1, Steam::ImportRun.count
    end

    test "a player is refused an unknown run with 403, not 404" do
      sign_in(accounts_players(:player))

      get back_office_import_run_path("nope", locale: :fr)

      assert_response :forbidden
    end
  end
end
