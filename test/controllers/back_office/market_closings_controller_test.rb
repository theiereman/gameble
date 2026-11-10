require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketClosingsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketSettings
    include SteamSignIn

    setup do
      Game::Market::Settings.delete_all
      @current = open_market!(first_opened_at: 2.days.ago)
    end

    def close_params(**overrides)
      { token: @current.token, message_fr: "Le marché ferme", message_en: "The market closes" }.merge(overrides)
    end

    def close_market_with(**overrides)
      post back_office_market_closing_path(locale: :en), params: { market_closing: close_params(**overrides) }
    end

    test "an administrator closes the market and the announcement is shown" do
      sign_in(accounts_players(:administrator))

      close_market_with

      assert_redirected_to back_office_market_path(locale: :en)
      assert_equal "The market is closed and the announcement is on the banner.", flash[:notice]
      assert_not Game::Market::MarketState.call.open?
      assert_equal [ "The market closes" ], Accounts::Announcement.where(shown: true).pluck(:message_en)
    end

    test "a missing announcement closes nothing and keeps what was typed" do
      sign_in(accounts_players(:administrator))

      assert_no_difference -> { Game::Market::Settings.count } do
        close_market_with(message_fr: "", message_en: "Typed text")
      end

      assert_response :unprocessable_content
      assert_select "[data-market-closing-refusal]", /both languages.*not closed/
      assert_select "textarea[name='market_closing[message_en]']", "Typed text"
      assert Game::Market::MarketState.call.open?
    end

    test "a stale page closes nothing and is redrawn with the stale line" do
      sign_in(accounts_players(:administrator))

      assert_no_difference -> { Game::Market::Settings.count } do
        close_market_with(token: "stale")
      end

      assert_response :unprocessable_content
      assert_select "[data-market-closing-refusal]", /Another administrator/
      assert_select "textarea[name='market_closing[message_en]']", "The market closes"
    end

    test "no token at all is a stale page" do
      sign_in(accounts_players(:administrator))

      assert_no_difference -> { Game::Market::Settings.count } do
        post back_office_market_closing_path(locale: :en)
      end

      assert_response :unprocessable_content
      assert_select "[data-market-closing-refusal]", /Another administrator/
    end

    test "a moderator is refused and nothing is written" do
      sign_in(accounts_players(:moderator))

      assert_no_difference -> { Game::Market::Settings.count } do
        close_market_with
      end

      assert Game::Market::MarketState.call.open?
    end

    test "a player and a visitor see an unknown address" do
      sign_in(accounts_players(:player))

      close_market_with

      assert_unknown_address
      assert Game::Market::MarketState.call.open?
    end
  end
end
