require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketOpeningsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketSettings
    include SteamSignIn

    setup do
      Game::Market::Settings.delete_all
      close_market!
    end

    def open_params(**overrides)
      { terms_confirmed: "1", odds_confirmed: "1", message_fr: "Le marché ouvre", message_en: "The market opens" }.merge(overrides)
    end

    test "an administrator opens the market and the announcement is shown" do
      sign_in(accounts_players(:administrator))

      post back_office_market_opening_path(locale: :en), params: open_params

      assert_redirected_to back_office_market_path(locale: :en)
      assert Game::Market::MarketState.call.open?
      assert_equal [ "The market opens" ], Accounts::Announcement.where(shown: true).pluck(:message_en)
    end

    test "a missing confirmation opens nothing and names the missing one, keeping what was typed" do
      sign_in(accounts_players(:administrator))

      assert_no_difference -> { Game::Market::Settings.count } do
        post back_office_market_opening_path(locale: :en), params: open_params(odds_confirmed: "0", message_en: "Typed text")
      end

      assert_response :unprocessable_content
      assert_select "[data-market-opening-refusal]", /odds/
      assert_select "textarea[name=message_en]", "Typed text"
      assert_select "input#market-terms-confirmed[checked]"
    end

    test "a refused announcement opens nothing" do
      sign_in(accounts_players(:administrator))

      assert_no_difference -> { Game::Market::Settings.count } do
        post back_office_market_opening_path(locale: :en), params: open_params(message_fr: "")
      end

      assert_response :unprocessable_content
      assert_select "[data-market-opening-refusal]"
    end

    test "a moderator is refused and nothing is written" do
      sign_in(accounts_players(:moderator))

      assert_no_difference -> { Game::Market::Settings.count } do
        post back_office_market_opening_path(locale: :en), params: open_params
      end

      assert_not Game::Market::MarketState.call.open?
    end

    test "a player sees an unknown address" do
      sign_in(accounts_players(:player))

      post back_office_market_opening_path(locale: :en), params: open_params

      assert_unknown_address
      assert_not Game::Market::MarketState.call.open?
    end
  end
end
