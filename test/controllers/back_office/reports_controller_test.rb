require "test_helper"
require_relative "../../support/counting_rate_limit"

module BackOffice
  class ReportsControllerTest < ActionDispatch::IntegrationTest
    include CountingRateLimit

    setup do
      OmniAuth.config.test_mode = true
      @target = accounts_players(:player)
      @target.update!(persona_name: "Gabe")
      @administrator = accounts_players(:administrator)
      @reporters = (1..3).map { Accounts::Player.create!(steam_id: "7656119796035000#{it}") }
      report(@target, @reporters[0], "cheating", 2.hours.ago)
      report(@target, @reporters[1], "cheating", 3.hours.ago)
      report(@target, @reporters[2], "harassment", 4.hours.ago)
      report(@administrator, @reporters[0], "other", 1.hour.ago)
    end

    teardown do
      OmniAuth.config.mock_auth.delete(:steam)
      OmniAuth.config.test_mode = false
    end

    def report(reported, reporter, reason, at)
      Accounts::Report.create!(reporter:, reported:, reason:, created_at: at)
    end

    def sign_in(player)
      OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
      post "/auth/steam", params: { origin: "/fr" }
      follow_redirect!
      assert_equal player.id, session[:player_id]
    end

    def row(player) = "tr[data-player-token='#{player.token}']"

    test "a moderator reads the queue: the latest report first, the counts per reason, BANNIR or the refusal, CLASSER" do
      moderator = accounts_players(:moderator)
      sign_in(moderator)

      get back_office_reports_path(locale: :fr)

      assert_response :success
      assert_select "h1", "Les signalements"
      assert_select "tbody tr", 2
      assert_select "tbody tr:first-child[data-player-token='#{@administrator.token}']"
      assert_select "#{row(@target)} a[href='/fr/brothers/#{@target.token}']", "Gabe"
      assert_select "#{row(@target)} td[data-report-reason=cheating]", "2"
      assert_select "#{row(@target)} td[data-report-reason=harassment]", "1"
      assert_select "#{row(@target)} td[data-report-reason=other]", "0"
      assert_select "#{row(@target)} td[data-report-total='3']", "3"
      assert_select "#{row(@target)} form[action='/fr/back-office/bans'][method=post][data-turbo-confirm]" do
        assert_select "input[type=hidden][name=token][value='#{@target.token}']"
        assert_select "button.button--danger", "BANNIR"
      end
      assert_select "#{row(@target)} form[action='/fr/back-office/reports/#{@target.token}/dismiss'][data-turbo-confirm] button", "CLASSER"
      assert_select "#{row(@administrator)} form[action='/fr/back-office/bans']", false
      assert_select "#{row(@administrator)} [data-ban-refusal=cannot_ban_administrator]",
        I18n.t("errors.accounts.cannot_ban_administrator", locale: :fr)
      [ @target, @administrator, moderator ].each { |player| assert_not_includes response.body, player.id.to_s }
    end

    test "an administrator reads the queue in English, their own row refused" do
      sign_in(@administrator)

      get back_office_reports_path(locale: :en)

      assert_select "h1", "The reports"
      assert_select "#{row(@administrator)} [data-ban-refusal=cannot_ban_self]"
      assert_select "#{row(@administrator)} [data-dismiss-refusal=cannot_dismiss_self]",
        I18n.t("errors.accounts.cannot_dismiss_self", locale: :en)
      assert_select "#{row(@administrator)} form", false
      assert_select "#{row(@target)} button", "BAN"
      assert_select "#{row(@target)} button", "DISMISS"
    end

    test "an empty queue says so" do
      Accounts::Report.update_all(handled_at: Time.current)
      sign_in(accounts_players(:moderator))

      get back_office_reports_path(locale: :fr)

      assert_select "tbody", false
      assert_select "main .panel", I18n.t("back_office.reports.index.empty", locale: :fr)
    end

    test "a moderator classes a player's reports: the row leaves the queue" do
      sign_in(accounts_players(:moderator))

      post back_office_dismiss_reports_path(locale: :fr, token: @target.token)

      assert_redirected_to back_office_reports_path(locale: :fr)
      assert_equal I18n.t("back_office.reports.dismiss.dismissed", name: "Gabe", locale: :fr), flash[:notice]
      follow_redirect!
      assert_select row(@target), false
      assert_select row(@administrator)
    end

    test "classing reports already classed, or an unknown player's, is refused" do
      sign_in(accounts_players(:moderator))
      post back_office_dismiss_reports_path(locale: :fr, token: @target.token)

      post back_office_dismiss_reports_path(locale: :fr, token: @target.token)
      assert_redirected_to back_office_reports_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.no_open_reports", locale: :fr), flash[:alert]

      post back_office_dismiss_reports_path(locale: :fr, token: "A" * 24)
      assert_equal I18n.t("errors.accounts.player_not_found", locale: :fr), flash[:alert]
    end

    test "a staff member cannot class the reports against themselves" do
      sign_in(@administrator)

      post back_office_dismiss_reports_path(locale: :fr, token: @administrator.token)

      assert_redirected_to back_office_reports_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.cannot_dismiss_self", locale: :fr), flash[:alert]
      assert_nil Accounts::Report.find_by(reported: @administrator).handled_at
    end

    test "the second page of the queue holds the 51st player, the oldest report" do
      reporter = @reporters.first
      49.times do |index|
        player = Accounts::Player.create!(steam_id: "765611979603510#{index.to_s.rjust(2, "0")}")
        report(player, reporter, "other", (index + 1).minutes.ago)
      end
      sign_in(accounts_players(:moderator))

      get back_office_reports_path(locale: :fr)
      assert_select "tbody tr", 50
      assert_select row(@target), false
      assert_select "a[href='/fr/back-office/reports?page=2']"

      get back_office_reports_path(locale: :fr, page: 2)

      assert_response :success
      assert_select "tbody tr", 1
      assert_select row(@target)
      assert_select "a[href='/fr/back-office/reports?page=1']"
    end

    test "more than 30 dismissals a minute are throttled" do
      sign_in(accounts_players(:moderator))

      with_counting_rate_limit(ReportsController) do
        30.times do
          post back_office_dismiss_reports_path(locale: :fr, token: @target.token)
          assert_redirected_to back_office_reports_path(locale: :fr)
        end

        post back_office_dismiss_reports_path(locale: :fr, token: @target.token)
      end

      assert_response :too_many_requests
    end

    test "a player is refused the queue and classing with 403" do
      sign_in(@target)

      get back_office_reports_path(locale: :fr)
      assert_response :forbidden

      post back_office_dismiss_reports_path(locale: :fr, token: @administrator.token)
      assert_response :forbidden
      assert_nil Accounts::Report.find_by(reported: @administrator).handled_at
    end

    test "a visitor is sent to sign in" do
      get back_office_reports_path(locale: :fr)
      assert_redirected_to home_path(locale: :fr)
      assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]

      post back_office_dismiss_reports_path(locale: :fr, token: @target.token)
      assert_redirected_to home_path(locale: :fr)
      assert Accounts::Report.where(reported: @target, handled_at: nil).exists?
    end
  end
end
