require "test_helper"
require_relative "../../support/steam_api_stubs"
require_relative "../../support/catalog_seeds"
require_relative "../../support/counting_rate_limit"

module BackOffice
  # The Steam import page of the back-office (AD-19), administrators only.
  class ImportRunsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper
    include SteamApiStubs
    include CatalogSeeds
    include CountingRateLimit

    setup do
      OmniAuth.config.test_mode = true
      stub_steam_api
    end

    teardown do
      unstub_steam_api
      OmniAuth.config.mock_auth.delete(:steam)
      OmniAuth.config.test_mode = false
    end

    def sign_in(player)
      OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
      post "/auth/steam", params: { origin: "/fr" }
      follow_redirect!
      assert_equal player.id, session[:player_id]
    end

    # No job is enqueued but the signed-in player's last-seen write, which
    # any request may enqueue (story 5.3).
    def assert_no_import_jobs(&)
      assert_no_enqueued_jobs(except: Accounts::NoteLastSeenJob, &)
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
      assert_select "main .panel", /No import has run yet/
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

      assert_no_import_jobs { post back_office_import_runs_path(locale: :en) }

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

    test "a run on the app list does not show the review counts" do
      sign_in(accounts_players(:administrator))
      run = running_run

      get back_office_import_run_path(run, locale: :en)

      assert_select "[data-import-run-apps-reviewed]", false
      assert_select "[data-import-run-apps-kept]", false
      assert_select "[data-import-run-apps-excluded]", false
    end

    test "a run goes through every step, keeps only the games that can become cards, and its page shows the counts" do
      sign_in(accounts_players(:administrator))
      stub_app_list_page(after: 0, appids: [ 10, 20, 30 ], more: true)
      stub_app_list_page(after: 30, appids: [ 40, 50, 60 ], more: false)
      stub_get_tag_list
      english = {
        10 => detailed_item(10, name: "Portal 2", description: "The <b>sequel</b> &amp; more.", reviews: 12_000,
          release: { "steam_release_date" => 1_303_171_200 }, publishers: [ "Valve", " " ]),
        20 => detailed_item(20, reviews: 499),
        30 => detailed_item(30, type: 4, reviews: 500),
        40 => unreviewed_item(40),
        50 => nil,
        60 => detailed_item(60, capsule: nil, reviews: 800)
      }
      french = { 10 => french_item(10, name: "Portal 2", description: "La <i>suite</i>.") }
      items_calls = stub_get_items_by_language("english" => english, "french" => french)

      perform_enqueued_jobs { post back_office_import_runs_path(locale: :fr) }

      run = Steam::ImportRun.sole
      assert_predicate run, :completed?
      assert_equal [ 10, 30, 60 ], Steam::App.kept_by(run).order(:appid).pluck(:appid)
      assert_equal({ 20 => "too_few_reviews", 40 => "too_few_reviews", 50 => "unavailable" },
        Steam::App.where.not(review_exclusion: nil).order(:appid).pluck(:appid, :review_exclusion).to_h)
      assert_equal({ 30 => "not_a_game", 60 => "no_vertical_image" },
        Steam::App.where.not(details_exclusion: nil).order(:appid).pluck(:appid, :details_exclusion).to_h)
      assert_equal 3, items_calls.size

      app = Steam::App.ready_by(run).sole
      assert_equal 10, app.appid
      assert_equal [ "Portal 2", "Portal 2" ], [ app.name_en, app.name_fr ]
      assert_equal [ "The sequel & more.", "La suite." ], [ app.short_description_en, app.short_description_fr ]
      assert_equal Date.new(2011, 4, 19), app.release_on
      assert_equal [ "Valve" ], app.publishers
      assert_equal [ 492, 19 ], app.tag_ids
      assert_equal %w[Indie Action], app.tag_ids.map { |tagid| Steam::Tag.find_by!(tagid: tagid).name }
      assert_equal "https://store.steampowered.com/app/10/Portal_2/", app.store_url
      assert_equal "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/10/library_600x900.jpg?t=1745363004", app.image_url

      get back_office_import_run_path(run, locale: :fr)

      assert_select "[data-import-run-status=completed]", "Terminé"
      assert_select "[data-import-run-step=cards]", /Inscription des cartes/
      assert_select "[data-import-run-apps-listed='6']", "6"
      assert_select "[data-import-run-apps-reviewed='6']", "6"
      assert_select "[data-import-run-apps-kept='3']", "3"
      assert_select "[data-import-run-apps-excluded='3']", "3"
      assert_select "[data-import-run-tags-named='3']", "3"
      assert_select "[data-import-run-apps-detailed='3']", "3"
      assert_select "[data-import-run-apps-excluded-details='2']", "2"
      assert_select "[data-import-run-cards-written='1']", "1"
      assert_select "[data-import-run-cards-refused='0']", "0"
      assert_select "dt", "Jeux retenus"
      assert_select "dt", "Étiquettes nommées"
    end

    test "a full run writes the three ready games as cards into the draft season, a second identical run leaves three, and the page shows them" do
      sign_in(accounts_players(:administrator))
      stub_app_list_page(after: 0, appids: [ 10, 20, 30, 40, 50 ], more: false)
      stub_get_tag_list(19 => "Action", 492 => "Indie", 1664 => "Puzzle", 1663 => "FPS")
      portal_tags = [ { "tagid" => 19, "weight" => 900 }, { "tagid" => 492, "weight" => 1200 }, { "tagid" => 1663, "weight" => 300 }, { "tagid" => 1664, "weight" => 800 } ]
      english = {
        10 => detailed_item(10, name: "Portal 2", tags: portal_tags, reviews: 12_000),
        20 => detailed_item(20, reviews: 499),
        30 => detailed_item(30, capsule: nil, reviews: 800),
        40 => detailed_item(40, reviews: 600),
        50 => detailed_item(50, publishers: [], reviews: 90_000)
      }
      french = { 10 => french_item(10, name: "Portal 2"), 40 => french_item(40), 50 => french_item(50) }
      stub_get_items_by_language("english" => english, "french" => french)

      perform_enqueued_jobs { post back_office_import_runs_path(locale: :en) }

      run = Steam::ImportRun.sole
      assert_predicate run, :completed?
      assert_equal "cards", run.step
      assert_equal [ 3, 0 ], [ run.cards_written, run.cards_refused ]
      draft = Catalog::DraftSeason.call
      cards = Catalog::Card.where(source_key: %w[steam:10 steam:40 steam:50]).index_by(&:source_key)
      assert_equal 3, cards.size
      assert_equal cards.values.map(&:id).sort, draft.card_seasons.pluck(:card_id).sort
      portal = cards.fetch("steam:10")
      assert_equal "portal-2", portal.slug
      assert_equal [ Date.new(2011, 4, 19), "Publisher 10", %w[puzzle fps], %w[indie action puzzle fps] ],
        [ portal.release_date, portal.publisher, portal.genres, portal.tags ]
      assert_equal [], cards.fetch("steam:40").genres, "no listed genre tag: no genre"
      assert_equal "https://store.steampowered.com/app/10/Portal_2/", portal.store_url
      assert_equal "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/10/library_600x900.jpg?t=1745363004", portal.image_url
      assert_equal({ "en" => [ "Portal 2", "The best game 10." ], "fr" => [ "Portal 2", "Le meilleur jeu 10." ] },
        portal.texts.to_h { |text| [ text.locale, [ text.title, text.short_description ] ] })
      assert_nil cards.fetch("steam:50").publisher
      draft.card_seasons.each do |card_season|
        assert_operator card_season.prestige_score, :>, 0
        assert_equal BigDecimal("90"), card_season.rating
      end
      assert_operator cards.fetch("steam:50").card_seasons.sole.prestige_score, :>, cards.fetch("steam:40").card_seasons.sole.prestige_score

      perform_enqueued_jobs { post back_office_import_runs_path(locale: :en) }

      second = Steam::ImportRun.latest_first.first
      assert_not_equal run, second
      assert_predicate second, :completed?
      assert_equal 3, second.cards_written
      assert_equal 3, Catalog::Card.where("source_key LIKE 'steam:%'").count
      assert_equal 3, Catalog::DraftSeason.call.card_seasons.count

      get back_office_import_run_path(second, locale: :en)

      assert_select "[data-import-run-step=cards]", /Writing the cards/
      assert_select "[data-import-run-cards-written='3']", "3"
      assert_select "[data-import-run-cards-refused='0']", "0"
      assert_select "[data-import-run-cards-removed='0']", "0"
      assert_select "dt", "Cards written"
      assert_select "dt", "Cards struck from the draft"
    end

    test "a completed run shows the cards struck from the draft; a run before its cards, or still in its cards pass, does not" do
      sign_in(accounts_players(:administrator))
      run = Steam::ImportRun.create!(status: :completed, step: "cards", counts: { "cards_written" => 2, "cards_removed" => 1 }, finished_at: 1.minute.ago)

      get back_office_import_run_path(run, locale: :fr)
      assert_select "[data-import-run-cards-removed='1']", "1"
      assert_select "dt", "Cartes rayées du brouillon"

      run.update!(status: :failed)
      get back_office_import_run_path(run, locale: :fr)
      assert_select "[data-import-run-cards-written='2']"
      assert_select "[data-import-run-cards-removed]", false

      run.update!(status: :completed, step: "details")
      get back_office_import_run_path(run, locale: :fr)
      assert_select "[data-import-run-cards-removed]", false
    end

    test "a run on the review pass does not show the counts of the later steps" do
      sign_in(accounts_players(:administrator))
      run = Steam::ImportRun.create!(status: :running, step: "reviews", cursor: { "step" => "reviews", "last_appid" => 0 }, started_at: 1.minute.ago)

      get back_office_import_run_path(run, locale: :en)

      assert_select "[data-import-run-apps-reviewed]"
      assert_select "[data-import-run-tags-named]", false
      assert_select "[data-import-run-apps-detailed]", false
    end

    test "a run on the details step shows the tags and details counts, not the cards" do
      sign_in(accounts_players(:administrator))
      run = Steam::ImportRun.create!(status: :running, step: "details", cursor: { "step" => "details", "last_appid" => 0 }, started_at: 1.minute.ago,
        counts: { "tags_named" => 450, "apps_detailed" => 1200, "apps_excluded_details" => 30 })

      get back_office_import_run_path(run, locale: :en)

      assert_select "[data-import-run-step=details]", /Copying the store pages/
      assert_select "[data-import-run-tags-named='450']", "450"
      assert_select "[data-import-run-apps-detailed='1200']", "1,200"
      assert_select "[data-import-run-apps-excluded-details='30']", "30"
      assert_select "[data-import-run-cards-written]", false
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

    test "an older failed run's page does not offer to resume" do
      sign_in(accounts_players(:administrator))
      older = Steam::ImportRun.create!(status: :failed, step: "app_list", cursor: { "last_appid" => 42 }, created_at: 2.days.ago, started_at: 2.days.ago, finished_at: 2.days.ago)
      Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

      get back_office_import_run_path(older, locale: :en)

      assert_select "[data-import-run-status=failed]"
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

    test "resuming a failed run that is not the latest is refused with not_latest" do
      sign_in(accounts_players(:administrator))
      older = Steam::ImportRun.create!(status: :failed, step: "app_list", cursor: { "last_appid" => 42 }, created_at: 2.days.ago, started_at: 2.days.ago, finished_at: 2.days.ago)
      Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

      assert_no_import_jobs { post resume_back_office_import_run_path(older, locale: :en) }

      assert_redirected_to back_office_import_run_path(older, locale: :en)
      assert_equal I18n.t("errors.steam.not_latest", locale: :en), flash[:alert]
      assert_predicate older.reload, :failed?
    end

    test "the latest completed run's page offers to rescore its cards; an older or unfinished run's does not" do
      sign_in(accounts_players(:administrator))
      Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
      older = Steam::ImportRun.create!(status: :completed, step: "cards", created_at: 2.days.ago, finished_at: 2.days.ago)
      latest = Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

      get back_office_import_run_path(latest, locale: :fr)

      assert_select "form[action='/fr/back-office/import-runs/#{latest.token}/rescore'][data-turbo-confirm] button", "Recalculer les cartes"
      assert_select "turbo-frame form[action$='/rescore']", false

      get back_office_import_run_path(older, locale: :fr)
      assert_select "form[action$='/rescore']", false

      get back_office_import_run_path(failed_run, locale: :fr)
      assert_select "form[action$='/rescore']", false
    end

    test "once the draft is published the latest run's page no longer offers to rescore" do
      sign_in(accounts_players(:administrator))
      run = Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.hour.ago)
      Catalog::Season.create!(status: :published, number: Catalog::Season.next_number, published_at: 1.minute.ago)

      get back_office_import_run_path(run, locale: :en)
      assert_select "form[action$='/rescore']", false

      Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
      get back_office_import_run_path(run, locale: :en)
      assert_select "form[action$='/rescore']", false

      assert_no_import_jobs { post rescore_back_office_import_run_path(run, locale: :en) }
      assert_equal I18n.t("errors.steam.already_published", locale: :en), flash[:alert]
      assert_predicate run.reload, :completed?
    end

    test "rescoring while another run is unfinished has its own message" do
      sign_in(accounts_players(:administrator))
      Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
      Steam::ImportRun.create!(status: :running, step: "app_list", started_at: 1.day.ago, created_at: 1.day.ago)
      run = Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

      assert_no_import_jobs { post rescore_back_office_import_run_path(run, locale: :en) }

      assert_equal I18n.t("back_office.import_runs.rescore.run_in_progress", locale: :en), flash[:alert]
    end

    test "an administrator rescores the latest completed run: it goes back on its cards step" do
      sign_in(accounts_players(:administrator))
      Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
      run = Steam::ImportRun.create!(status: :completed, step: "cards", cursor: { "step" => "cards", "last_appid" => 99 }, finished_at: 1.minute.ago)

      assert_enqueued_with(job: Steam::ImportStepJob, args: [ run.id, { "step" => "cards", "last_appid" => 0 } ], queue: "import") do
        post rescore_back_office_import_run_path(run, locale: :en)
      end

      assert_redirected_to back_office_import_run_path(run, locale: :en)
      assert_equal I18n.t("back_office.import_runs.rescore.rescoring", locale: :en), flash[:notice]
      assert_predicate run.reload, :running?
      assert_equal "cards", run.step
    end

    test "rescoring a run that is not the latest completed one is refused" do
      sign_in(accounts_players(:administrator))
      run = failed_run

      assert_no_import_jobs { post rescore_back_office_import_run_path(run, locale: :en) }

      assert_redirected_to back_office_import_run_path(run, locale: :en)
      assert_equal I18n.t("errors.steam.not_completed", locale: :en), flash[:alert]
      assert_predicate run.reload, :failed?
    end

    # Abandon

    test "an administrator abandons the latest run that failed before its cards: the draft can be published and a new import started" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))
      run = Steam::ImportRun.create!(status: :failed, step: "details", cursor: { "step" => "details", "last_appid" => 300 }, counts: { "apps_listed" => 7 },
        started_at: 1.hour.ago, finished_at: 1.minute.ago, error_messages: [ { "at" => 1.minute.ago.utc.iso8601, "message" => "Steam::WebApi::Error: boom" } ])

      get back_office_import_run_path(run, locale: :fr)
      assert_select "form[action='/fr/back-office/import-runs/#{run.token}/abandon'][data-turbo-confirm] button", "Abandonner cette passe"
      assert_select "turbo-frame form[action$='/abandon']", false

      post abandon_back_office_import_run_path(run, locale: :fr)

      assert_redirected_to back_office_import_run_path(run, locale: :fr)
      follow_redirect!
      assert_equal I18n.t("back_office.import_runs.abandon.abandoned", locale: :fr), flash[:notice]
      assert_predicate run.reload, :abandoned?
      assert_select "[data-import-run-status=abandoned]", "Abandonné"
      assert_select "form[action$='/resume']", false
      assert_select "form[action$='/rescore']", false
      assert_select "form[action$='/abandon']", false
      assert_select ".ledger-errors li", /boom/

      post publish_back_office_seasons_path(locale: :fr), params: { number: draft.number }
      assert_equal I18n.t("back_office.seasons.publish.published", number: draft.number, locale: :fr), flash[:notice]
      assert_predicate draft.reload, :published?

      assert_enqueued_with(job: Steam::ImportStepJob) { post back_office_import_runs_path(locale: :fr) }
      assert_predicate Steam::ImportRun.latest_first.first, :running?
    end

    test "a latest run that failed after writing cards offers to resume and explains why it cannot be abandoned" do
      sign_in(accounts_players(:administrator))
      run = Steam::ImportRun.create!(status: :failed, step: "cards", cursor: { "step" => "cards", "last_appid" => 620 },
        counts: { "cards_written" => 100, "cards_removed" => 0 }, started_at: 1.hour.ago, finished_at: 1.minute.ago)

      get back_office_import_run_path(run, locale: :en)

      assert_select "form[action$='/resume'] button", "Resume from where it stopped"
      assert_select "form[action$='/abandon']", false
      assert_select "main .panel", I18n.t("back_office.import_runs.show.cards_written_note", locale: :en)
      assert_select "[data-import-run-cards-removed]", false, "counted only once the pass ends"

      post abandon_back_office_import_run_path(run, locale: :en)

      assert_redirected_to back_office_import_run_path(run, locale: :en)
      assert_equal I18n.t("errors.steam.cards_written", locale: :en), flash[:alert]
      assert_predicate run.reload, :failed?
    end

    test "a run that is running, completed or not the latest offers no abandon, and abandoning it is refused" do
      sign_in(accounts_players(:administrator))
      older = Steam::ImportRun.create!(status: :failed, step: "app_list", created_at: 2.days.ago, started_at: 2.days.ago, finished_at: 2.days.ago)
      completed = Steam::ImportRun.create!(status: :completed, step: "cards", finished_at: 1.minute.ago)

      { older => "not_latest", completed => "not_abandonable" }.each do |run, code|
        get back_office_import_run_path(run, locale: :en)
        assert_select "form[action$='/abandon']", false
        assert_select "main .panel", { text: I18n.t("back_office.import_runs.show.cards_written_note", locale: :en), count: 0 }

        post abandon_back_office_import_run_path(run, locale: :en)

        assert_equal I18n.t("errors.steam.#{code}", locale: :en), flash[:alert], code
      end
      assert_predicate older.reload, :failed?

      completed.update!(status: :running, finished_at: nil)
      get back_office_import_run_path(completed, locale: :en)
      assert_select "form[action$='/abandon']", false
      post abandon_back_office_import_run_path(completed, locale: :en)
      assert_equal I18n.t("errors.steam.not_abandonable", locale: :en), flash[:alert]
      assert_predicate completed.reload, :running?
    end

    test "more than 10 abandons a minute are throttled" do
      sign_in(accounts_players(:administrator))
      run = running_run

      with_counting_rate_limit(ImportRunsController) do
        10.times do
          post abandon_back_office_import_run_path(run, locale: :en)
          assert_redirected_to back_office_import_run_path(run, locale: :en)
        end

        post abandon_back_office_import_run_path(run, locale: :en)
      end

      assert_response :too_many_requests
    end

    test "abandoning an unknown run is not found" do
      sign_in(accounts_players(:administrator))

      post abandon_back_office_import_run_path("nope", locale: :en)

      assert_response :not_found
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
      yield :post, rescore_back_office_import_run_path(run, locale: :fr)
      yield :post, abandon_back_office_import_run_path(run, locale: :fr)
    end

    [ :player, :moderator ].each do |role|
      test "a #{role} is refused every import action with 403" do
        run = failed_run
        sign_in(accounts_players(role))

        each_request(run) do |verb, path|
          assert_no_import_jobs { public_send(verb, path) }

          assert_response :forbidden, "#{verb} #{path}"
          assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
        end
        assert_predicate run.reload, :failed?
        assert_equal 1, Steam::ImportRun.count
      end
    end

    test "a visitor is sent to the hub and asked to sign in for every import action" do
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
