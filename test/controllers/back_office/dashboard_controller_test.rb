require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    def sign_in_origin = "/fr"

    [ :moderator, :administrator ].each do |role|
      test "a #{role} opens the back-office, with the moderation tiles and no report waiting" do
        sign_in(accounts_players(role))

        get back_office_path(locale: :fr)

        assert_response :success
        assert_select "h1", "Le back-office de la Confrérie"
        assert_select "#office-group-moderation", "Modération"
        assert_select "a.office-tile[href='/fr/back-office/reports'] .office-tile__title", "Les signalements"
        assert_select "a.office-tile[href='/fr/back-office/bans'] .office-tile__title", "Les bannis"
        assert_select "a.office-tile[href='/fr/back-office/history'] .office-tile__title", "L'historique"
        assert_select "a.office-tile[href='/fr/back-office/reports'] svg.pixel-icon"
        assert_select "a.office-tile[href='/fr/back-office/reports'] .office-tile__status", false
        assert_select ".top-bar__start > a.top-bar__home:first-child[href='/fr']"
        assert_select ".top-bar__start > a.button--secondary[href='/fr']", "Pont"
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

      assert_select "a.office-tile--urgent[href='/fr/back-office/reports'] .office-tile__status--count", "2 en attente"
    end

    test "a moderator sees the moderation group and the market's" do
      sign_in(accounts_players(:moderator))

      get back_office_path(locale: :fr)

      assert_equal %w[Modération Marché], css_select(".office-group__heading").map(&:text)
      assert_select "a.office-tile", 5
      assert_select "a[href='/fr/back-office/themes']", false
    end

    test "an administrator sees every tool, grouped, the job queue outside Turbo" do
      sign_in(accounts_players(:administrator))

      get back_office_path(locale: :fr)

      assert_equal %w[Modération Catalogue Communication Marché Technique], css_select(".office-group__heading").map(&:text)
      assert_select "a.office-tile", 13
      assert_select "a.office-tile[data-office-tile='jobs'][data-turbo='false'][href='/back-office/jobs/']"
    end

    test "the back-office shows a live announcement on its tile" do
      Accounts::Announcement.create!(message_en: "Hello", message_fr: "Bonjour", shown: true)
      sign_in(accounts_players(:administrator))

      get back_office_path(locale: :fr)

      assert_select "a[data-office-tile='announcements'] .office-tile__status--live", "En ligne"
    end
  end
end
