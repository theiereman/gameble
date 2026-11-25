require "test_helper"
require_relative "../../support/steam_sign_in"

module BackOffice
  class SupportersControllerTest < ActionDispatch::IntegrationTest
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @administrator = accounts_players(:administrator)
      @moderator = accounts_players(:moderator)
      @player = accounts_players(:player)
    end

    def marked? = Game::PlayerState.where(player_id: @player.id).where.not(supporter_at: nil).exists?
    def row(player) = "tr[data-player-token='#{player.token}']"

    test "an administrator marks a supporter and comes back to the list with the search" do
      sign_in(@administrator)

      post back_office_supporters_path(locale: :fr), params: { token: @player.token, q: "gabe", page: "2" }

      assert_redirected_to back_office_players_path(locale: :fr, q: "gabe", page: 2)
      assert marked?
    end

    test "a moderator is forbidden and nothing is written" do
      sign_in(@moderator)

      post back_office_supporters_path(locale: :fr), params: { token: @player.token }

      assert_response :forbidden
      assert_not marked?
    end

    test "a repeat comes back with the alert" do
      sign_in(@administrator)
      2.times { post back_office_supporters_path(locale: :fr), params: { token: @player.token } }

      assert_equal I18n.t("errors.game.supporter_already_granted", locale: :fr), flash[:alert]
    end

    test "the players list shows the button to an administrator for an unmarked player in good standing only" do
      sign_in(@administrator)
      get back_office_players_path(locale: :fr)
      assert_select "#{row(@player)} form[action='/fr/back-office/supporters']"
      assert_select "#{row(accounts_players(:banned))} form[action='/fr/back-office/supporters']", false

      post back_office_supporters_path(locale: :fr), params: { token: @player.token }
      get back_office_players_path(locale: :fr)
      assert_select "#{row(@player)} form[action='/fr/back-office/supporters']", false
    end

    test "a moderator does not see the button" do
      sign_in(@moderator)

      get back_office_players_path(locale: :fr)

      assert_select "form[action='/fr/back-office/supporters']", false
    end

    test "the badge shows next to the name on the profile of a supporter only" do
      sign_in(@player)
      get me_path(locale: :fr)
      assert_select ".profile-band__name-row .supporter-badge", false

      Game::GrantSupporter.new.call(staff: @administrator, player: @player).value!
      get me_path(locale: :fr)
      assert_select ".profile-band__name-row h1#profile-heading + .supporter-badge[data-tip='#{I18n.t("public_profiles.supporter_tooltip", locale: :fr)}']", text: "VIP"
    end
  end
end
