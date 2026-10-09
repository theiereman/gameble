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
      test "a #{role} opens the back-office, with an empty queue and the moderation pages" do
        sign_in(accounts_players(role))

        get back_office_path(locale: :fr)

        assert_response :success
        assert_select "h1", "Le back-office de la Confrérie"
        assert_select "main .panel[data-report-queue-size='0']", "Aucun joueur signalé n'attend les officiers."
        assert_select "a[href='/fr/back-office/reports']", "Les signalements"
        assert_select "a[href='/fr/back-office/bans']", "Les bannis"
        assert_select ".top-bar__start > a.button--secondary:first-child[href='/fr']", "Pont"
        assert_select "a[href='/fr/back-office']", false
        assert_select "body.is-back-office"
        assert_select "#atmosphere", false
        assert_select ".tab-bar", false
      end
    end

    test "the back-office counts the reported players awaiting the staff" do
      reporters = (1..2).map { Accounts::Player.create!(steam_id: "7656119796037000#{it}") }
      [ accounts_players(:player), accounts_players(:administrator) ].each do |reported|
        reporters.each { |reporter| Accounts::Report.create!(reporter:, reported:, reason: "cheating") }
      end
      Accounts::Report.create!(reporter: reporters.first, reported: accounts_players(:banned), reason: "other")
      sign_in(accounts_players(:moderator))

      get back_office_path(locale: :fr)

      assert_select "main .panel[data-report-queue-size='2']", "2 joueurs signalés attendent les officiers."
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
