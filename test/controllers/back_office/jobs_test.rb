require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  # Mission Control Jobs at /back-office/jobs, administrators only (R7).
  # Tests run without Solid Queue, so the engine reads the test environment's
  # adapter: its dashboard renders, with no job in it.
  class JobsTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    def sign_in_origin = "/fr"

    test "an administrator opens the Mission Control dashboard" do
      sign_in(accounts_players(:administrator))

      get "/back-office/jobs"
      follow_redirect! while response.redirect? && response.location.include?("/back-office/jobs")

      assert_response :success
      assert_select "title", /Mission control/
    end

    test "the engine's HTTP basic auth is off" do
      sign_in(accounts_players(:administrator))

      get "/back-office/jobs"

      assert_nil response.headers["WWW-Authenticate"]
      assert_not_equal 401, response.status
    end

    test "a moderator is refused the job queue with 403" do
      sign_in(accounts_players(:moderator))

      get "/back-office/jobs"

      assert_response :forbidden
      assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :en))
    end

    test "a visitor and a player get the 404 of an unknown address" do
      get "/back-office/jobs"
      assert_unknown_address

      sign_in(accounts_players(:player))
      get "/back-office/jobs"
      assert_unknown_address
    end

    test "the back-office links to the job queue for an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :fr)

      assert_select "main a.button--secondary[href='/back-office/jobs/'][data-turbo=false]", "La file des tâches"

      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :fr)

      assert_response :success
      assert_select "a[href^='/back-office/jobs']", false
    end
  end
end
