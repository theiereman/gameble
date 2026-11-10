require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketSettings
    include SteamSignIn

    setup do
      Game::Market::Settings.delete_all
      close_market!
    end

    test "an administrator sees the state and the opening form of a market never opened" do
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_response :success
      assert_select "h1", "The market"
      assert_select "[data-market-state=closed]", /never been opened/
      assert_select "form[action='/en/back-office/market/opening'][method=post]" do
        assert_select "input[type=checkbox][name=terms_confirmed]:not([disabled])"
        assert_select "input[type=checkbox][name=odds_confirmed]:not([disabled])"
        assert_select "textarea[name=message_fr]:not([disabled])"
        assert_select "button", "Open the market"
      end
      assert_select "[style]", false
    end

    test "after a first opening the same form reopens the market" do
      open_market!(first_opened_at: 2.days.ago)
      close_market!(first_opened_at: 2.days.ago)
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :fr)

      assert_select "[data-market-state=closed]", /suspendu/
      assert_select "button", "Rouvrir le marché"
    end

    test "an open market shows its state and no form" do
      open_market!(first_opened_at: Time.current)
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_select "[data-market-state=open]"
      assert_select "form[action='/en/back-office/market/opening']", false
    end

    test "a moderator reads the page with every control disabled and the reason shown" do
      sign_in(accounts_players(:moderator))

      get back_office_market_path(locale: :en)

      assert_response :success
      assert_select "[data-market-opening-reason]", /administrator/
      assert_select "fieldset[disabled][aria-describedby=market-opening-reason]", 2
      assert_select "textarea:not([disabled])", false
      assert_select "button[disabled]", "Open the market"
      assert_select "button[type=submit]", false
    end

    test "a player and a visitor see an unknown address" do
      sign_in(accounts_players(:player))
      get back_office_market_path(locale: :en)
      assert_unknown_address
    end

    test "the dashboard leads staff to the market" do
      sign_in(accounts_players(:moderator))

      get back_office_path(locale: :en)

      assert_select "a[href='/en/back-office/market'] .office-tile__title", "The market"
    end

    test "the teaser still answers at the market's address once the market is open" do
      open_market!(first_opened_at: Time.current)

      get market_path(locale: :en)

      assert_response :success
      assert_select "h1", "The Brotherhood is building the market"
    end
  end
end
