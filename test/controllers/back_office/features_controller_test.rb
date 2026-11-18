require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The features still hidden from the players, switched on or off by an administrator.
  class FeaturesControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    test "an administrator sees each feature and whether it is on" do
      sign_in(accounts_players(:administrator))

      get back_office_features_path(locale: :en)

      assert_response :success
      assert_select "h1", "The features"
      assert_select "[data-feature=duels][data-enabled=true] h2", text: /Duels · On/
      assert_select "[data-feature=duels] button", "Switch off"
    end

    test "switching a feature off hides it from the players and switching it on shows it again" do
      sign_in(accounts_players(:administrator))

      patch back_office_feature_path(locale: :en, key: "duels"), params: { enabled: "0" }

      assert_redirected_to back_office_features_path(locale: :en)
      assert_equal "Duels is hidden from the players.", flash[:notice]
      assert_not_includes Game::EnabledFeatures.call, "duels"
      get duels_path(locale: :en)
      assert_response :not_found

      patch back_office_feature_path(locale: :en, key: "duels"), params: { enabled: "1" }

      assert_includes Game::EnabledFeatures.call, "duels"
      get duels_path(locale: :en)
      assert_response :success
    end

    test "a feature that does not exist is refused" do
      sign_in(accounts_players(:administrator))

      patch back_office_feature_path(locale: :en, key: "teleport"), params: { enabled: "1" }

      assert_redirected_to back_office_features_path(locale: :en)
      assert_equal "That feature does not exist.", flash[:alert]
    end

    test "a moderator reads and changes nothing, and the home does not link to it" do
      sign_in(accounts_players(:moderator))

      get back_office_path(locale: :en)
      assert_select "a[data-office-tile=features]", 0
      get back_office_features_path(locale: :en)
      assert_response :forbidden
      patch back_office_feature_path(locale: :en, key: "duels"), params: { enabled: "0" }
      assert_response :forbidden
      assert_includes Game::EnabledFeatures.call, "duels"
    end
  end
end
