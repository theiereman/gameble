require "test_helper"

module BackOffice
  # Mission Control Jobs at /back-office/jobs, administrators only (R7).
  # Development and test run without Solid Queue, so the engine reads the
  # default (async) adapter: its dashboard renders, with no job in it.
  class JobsTest < ActionDispatch::IntegrationTest
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

    [ :moderator, :player ].each do |role|
      test "a #{role} is refused the job queue with 403" do
        sign_in(accounts_players(role))

        get "/back-office/jobs"

        assert_response :forbidden
        assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :en))
      end
    end

    test "a visitor is sent to the attic and asked to sign in" do
      get "/back-office/jobs"

      assert_redirected_to "/en"
      assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
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
