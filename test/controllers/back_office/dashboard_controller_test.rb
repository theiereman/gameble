require "test_helper"

module BackOffice
  class DashboardControllerTest < ActionDispatch::IntegrationTest
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

    [ :moderator, :administrator ].each do |role|
      test "a #{role} opens the empty back-office" do
        sign_in(accounts_players(role))

        get back_office_path(locale: :fr)

        assert_response :success
        assert_select "h1", "Le back-office de la Confrérie"
        assert_select "main .panel", "Rien n'attend encore les officiers. Les registres sont vierges."
        assert_select ".top-bar__start > a.button--secondary:first-child[href='/fr']", "Pont"
        assert_select "a[href='/fr/back-office']", false
        assert_select "body.is-back-office"
        assert_select "#atmosphere", false
        assert_select ".tab-bar", false
      end
    end

    test "the back-office answers in English" do
      sign_in(accounts_players(:administrator))

      get back_office_path(locale: :en)

      assert_select "h1", "The Brotherhood's back-office"
      assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    end

    test "a player is refused the back-office with 403" do
      sign_in(accounts_players(:player))

      get back_office_path(locale: :fr)

      assert_response :forbidden
      assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
      assert_select "h1", false
    end

    test "a visitor is sent to the hub and asked to sign in" do
      get back_office_path(locale: :fr)

      assert_redirected_to home_path(locale: :fr)
      assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]
    end
  end
end
