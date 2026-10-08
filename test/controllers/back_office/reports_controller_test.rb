require "test_helper"
require_relative "../../support/counting_rate_limit"

module BackOffice
  class ReportsControllerTest < ActionDispatch::IntegrationTest
    include CountingRateLimit

    setup do
      OmniAuth.config.test_mode = true
      @reporter = accounts_players(:player)
      @reported = Accounts::Player.create!(steam_id: "76561197960287921", persona_name: "Rude Rick")
      @reporter.update_columns(persona_name: "Polite Paula")
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

    def report(reported, reason, at, reporter: @reporter)
      Accounts::Report.create!(reporter:, reported:, reason:, created_at: at)
    end

    def queue_rows(token)
      css_select("[data-reported='#{token}'] tbody tr").map { |row| row.css("td").map { it.text.strip } }
    end

    def banned_tokens = css_select("[data-banned]").map { it["data-banned"] }
    def queued_tokens = css_select("[data-reported]").map { it["data-reported"] }

    [ :moderator, :administrator ].each do |role|
      test "a #{role} sees the reported players, the latest report first, and the banned players" do
        quiet = Accounts::Player.create!(steam_id: "76561197960287922")
        report(@reported, "cheating", Time.utc(2026, 10, 1, 9))
        report(quiet, "inappropriate_name", Time.utc(2026, 10, 2, 9))
        report(@reported, "harassment", Time.utc(2026, 10, 3, 9), reporter: quiet)
        report(accounts_players(:banned), "other", Time.utc(2026, 10, 4, 9))
        sign_in(accounts_players(role))

        get back_office_reports_path(locale: :en)

        assert_response :success
        assert_select "h1", "The reports"
        assert_equal [ @reported.token, quiet.token ], queued_tokens
        assert_select "[data-reported='#{@reported.token}'] h3 a[href='/en/brothers/#{@reported.token}']", "Rude Rick"
        quiet_code = Accounts::PublicProfile.code(quiet.token)
        assert_equal [
          [ "Harassment", "Player #{quiet_code}", "2026-10-03 09:00:00 UTC" ],
          [ "Cheating or abuse", "Polite Paula", "2026-10-01 09:00:00 UTC" ]
        ], queue_rows(@reported.token)
        assert_select "form[action='/en/back-office/players/#{@reported.token}/ban'][method=post][data-turbo-confirm]" do
          assert_select "button", "Ban Rude Rick"
        end
        assert_equal [ accounts_players(:banned).token ], banned_tokens
        assert_select "form[action='/en/back-office/players/#{accounts_players(:banned).token}/unban'][method=post][data-turbo-confirm]"
      end
    end

    test "a reported moderator does not see the reports on themselves" do
      moderator = accounts_players(:moderator)
      report(moderator, "cheating", 1.hour.ago)
      report(@reported, "other", 2.hours.ago, reporter: accounts_players(:administrator))
      sign_in(moderator)

      get back_office_reports_path(locale: :en)

      assert_equal [ @reported.token ], queued_tokens
      assert_not_includes response.body, "Polite Paula"
    end

    test "an administrator's reports show no Ban button" do
      administrator = accounts_players(:administrator)
      report(administrator, "cheating", 1.hour.ago)
      report(@reported, "other", 2.hours.ago)
      sign_in(accounts_players(:moderator))

      get back_office_reports_path(locale: :en)

      assert_equal [ administrator.token, @reported.token ], queued_tokens
      assert_select "[data-reported='#{administrator.token}'] form", false
      assert_select "[data-reported='#{@reported.token}'] form[action$='/ban']"
    end

    test "the reported name links to a public profile only" do
      report(@reported, "cheating", 1.hour.ago)
      sign_in(accounts_players(:moderator))

      %w[friends_only private].each do |visibility|
        @reported.update_columns(visibility:)
        get back_office_reports_path(locale: :en)

        assert_select "[data-reported='#{@reported.token}'] h3", "Rude Rick"
        assert_select "[data-reported='#{@reported.token}'] h3 a", false
      end

      @reported.update_columns(visibility: "public")
      get back_office_reports_path(locale: :en)

      assert_select "[data-reported='#{@reported.token}'] h3 a[href='/en/brothers/#{@reported.token}']", "Rude Rick"
    end

    test "the page answers in French, with empty lists" do
      accounts_players(:banned).update_columns(banned_at: nil)
      sign_in(accounts_players(:moderator))

      get back_office_reports_path(locale: :fr)

      assert_select "h1", "Les signalements"
      assert_select "[data-report-queue] .panel", "Aucun signalement n'attend, officier."
      assert_select "[data-banned-players] .panel", "Aucun joueur n'est banni."
    end

    test "a moderator bans a reported player: they leave the queue for the banned players" do
      report(@reported, "cheating", 1.hour.ago)
      sign_in(accounts_players(:moderator))

      post back_office_player_ban_path(locale: :en, token: @reported.token)

      assert_redirected_to back_office_reports_path(locale: :en)
      assert_response :see_other
      assert_equal I18n.t("back_office.bans.create.banned", locale: :en), flash[:notice]
      assert_predicate @reported.reload, :banned?
      assert_equal 1, Rails.configuration.event_store.read.of_type(Accounts::PlayerBanned).to_a.size
      follow_redirect!
      assert_empty queued_tokens
      assert_includes banned_tokens, @reported.token
      assert_equal 1, Accounts::Report.where(reported: @reported).count
    end

    test "an administrator unbans a player: they come back to the queue with their reports" do
      report(@reported, "cheating", 1.hour.ago)
      @reported.update!(banned_at: Time.current)
      sign_in(accounts_players(:administrator))

      post back_office_player_unban_path(locale: :fr, token: @reported.token)

      assert_redirected_to back_office_reports_path(locale: :fr)
      assert_equal I18n.t("back_office.bans.destroy.unbanned", locale: :fr), flash[:notice]
      assert_not @reported.reload.banned?
      assert_equal 1, Rails.configuration.event_store.read.of_type(Accounts::PlayerUnbanned).to_a.size
      follow_redirect!
      assert_equal [ @reported.token ], queued_tokens
      assert_not_includes banned_tokens, @reported.token
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} banning an administrator or themselves is refused with a message, and nothing changes" do
        actor = accounts_players(role)
        administrator = Accounts::Player.create!(steam_id: "76561197960287923", role: :administrator)
        sign_in(actor)

        post back_office_player_ban_path(locale: :en, token: administrator.token)
        assert_redirected_to back_office_reports_path(locale: :en)
        assert_equal I18n.t("errors.accounts.cannot_ban_administrator", locale: :en), flash[:alert]

        post back_office_player_ban_path(locale: :en, token: actor.token)
        assert_equal I18n.t("errors.accounts.cannot_ban_self", locale: :en), flash[:alert]

        assert_not administrator.reload.banned?
        assert_not actor.reload.banned?
        assert_empty Rails.configuration.event_store.read.of_type(Accounts::PlayerBanned).to_a
      end
    end

    test "banning twice, or unbanning a player not banned, is refused with a message" do
      sign_in(accounts_players(:moderator))

      post back_office_player_ban_path(locale: :fr, token: accounts_players(:banned).token)
      assert_equal I18n.t("errors.accounts.already_banned", locale: :fr), flash[:alert]

      post back_office_player_unban_path(locale: :fr, token: @reported.token)
      assert_equal I18n.t("errors.accounts.not_banned", locale: :fr), flash[:alert]
      assert_not @reported.reload.banned?
    end

    test "an unknown token is not found; a malformed one has no route" do
      sign_in(accounts_players(:moderator))

      post back_office_player_ban_path(locale: :en, token: "A" * 24)
      assert_equal I18n.t("errors.accounts.player_not_found", locale: :en), flash[:alert]

      post back_office_player_unban_path(locale: :en, token: "A" * 24)
      assert_equal I18n.t("errors.accounts.player_not_found", locale: :en), flash[:alert]

      post "/en/back-office/players/#{@reported.id}/ban"
      assert_response :not_found
      assert_not @reported.reload.banned?
    end

    test "more than 10 bans and unbans a minute are throttled" do
      sign_in(accounts_players(:moderator))

      with_counting_rate_limit(BansController) do
        5.times do
          post back_office_player_ban_path(locale: :en, token: @reported.token)
          assert_redirected_to back_office_reports_path(locale: :en)
          post back_office_player_unban_path(locale: :en, token: @reported.token)
          assert_redirected_to back_office_reports_path(locale: :en)
        end

        post back_office_player_ban_path(locale: :en, token: @reported.token)
      end

      assert_response :too_many_requests
      assert_not @reported.reload.banned?
    end

    test "a visitor is sent to the hub and asked to sign in, for the page and for a ban or an unban" do
      get back_office_reports_path(locale: :fr)
      assert_redirected_to home_path(locale: :fr)
      assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]

      post back_office_player_ban_path(locale: :fr, token: @reported.token)
      assert_redirected_to home_path(locale: :fr)
      assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]

      post back_office_player_unban_path(locale: :fr, token: accounts_players(:banned).token)
      assert_redirected_to home_path(locale: :fr)

      assert_not @reported.reload.banned?
      assert_predicate accounts_players(:banned).reload, :banned?
    end

    test "a player is refused the page, a ban and an unban with 403" do
      report(@reported, "cheating", 1.hour.ago)
      sign_in(accounts_players(:player))

      get back_office_reports_path(locale: :fr)
      assert_response :forbidden
      assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
      assert_not_includes response.body, "Rude Rick"

      post back_office_player_ban_path(locale: :fr, token: @reported.token)
      assert_response :forbidden

      post back_office_player_unban_path(locale: :fr, token: accounts_players(:banned).token)
      assert_response :forbidden

      assert_not @reported.reload.banned?
      assert_predicate accounts_players(:banned).reload, :banned?
    end

    [ :moderator, :administrator ].each do |role|
      test "the back-office links to the reports for a #{role}" do
        sign_in(accounts_players(role))

        get back_office_path(locale: :en)

        assert_select "a[href='/en/back-office/reports']", "The reports"
      end
    end
  end
end
