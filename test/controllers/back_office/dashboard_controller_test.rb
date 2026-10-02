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
        assert_select "main .text-plate", "Rien n'attend encore les officiers. Les registres sont vierges."
        assert_select ".status-band > a.button--secondary:first-child[href='/fr']", "Retour au grenier"
        assert_select "a[href='/fr/back-office']", false
      end
    end

    test "the back-office answers in English" do
      sign_in(accounts_players(:administrator))

      get back_office_path(locale: :en)

      assert_select "h1", "The Brotherhood's back-office"
      assert_select ".status-band > a.button--secondary[href='/en']", "Back to the attic"
    end

    test "a player is refused the back-office with 403" do
      sign_in(accounts_players(:player))

      get back_office_path(locale: :fr)

      assert_response :forbidden
      assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
      assert_select "h1", false
    end

    test "a visitor is sent to the attic and asked to sign in" do
      get back_office_path(locale: :fr)

      assert_redirected_to home_path(locale: :fr)
      assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]
    end
  end
end
