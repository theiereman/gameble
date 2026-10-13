require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    def sign_in_origin = "/fr"

    [ :moderator, :administrator ].each do |role|
      test "a #{role} opens the back-office, with an empty queue and the moderation pages" do
        sign_in(accounts_players(role))

        get back_office_path(locale: :fr)

        assert_response :success
        assert_select "h1", "Le back-office de la Confrérie"
        assert_select "main .panel[data-report-queue-size='0']", "Aucun joueur signalé n'attend les officiers."
        assert_select "a[href='/fr/back-office/reports']", "Les signalements"
        assert_select "a[href='/fr/back-office/bans']", "Les bannis"
        assert_select "a[href='/fr/back-office/history']", "L'historique"
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

      assert_select "main .panel[data-report-queue-size='2']", "2 joueurs signalés attendent les officiers."
    end

    test "the back-office answers in English" do
      sign_in(accounts_players(:administrator))

      get back_office_path(locale: :en)

      assert_select "h1", "The Brotherhood's back-office"
      assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    end

    test "a player gets the 404 of an unknown address" do
      sign_in(accounts_players(:player))

      get back_office_path(locale: :fr)

      assert_unknown_address
    end

    test "a visitor gets the 404 of an unknown address" do
      get back_office_path(locale: :fr)

      assert_unknown_address
      assert_nil flash[:alert]
    end
  end
end
