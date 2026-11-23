require "test_helper"
require_relative "../../support/alt_signal_seeds"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketSignalsControllerTest < ActionDispatch::IntegrationTest
    include AltSignalSeeds
    include HiddenBackOffice
    include SteamSignIn

    setup do
      Game::Market::AltSignal.delete_all
      Game::Market::TiedAccount.delete_all
      @alice = accounts_players(:player)
      @bob = accounts_players(:administrator)
      @now = Time.utc(2026, 11, 10, 0, 40)
      Game::Market::AltSignal.create!(account: @alice, signal: "near_maximum_opening", facts: { "days" => 4, "peak" => 130, "per_day" => 120 }, refreshed_at: @now)
      Game::Market::AltSignal.create!(account: @alice, signal: "one_way_trades", other_account: @bob,
        facts: { "trades" => 12, "given" => 48, "received" => 12 }, refreshed_at: @now)
      low, high = [ @alice, @bob ].minmax_by(&:id)
      Game::Market::TiedAccount.create!(low_account: low, high_account: high, signal: "one_way_trades",
        facts: { "trades" => 12, "given" => 48, "received" => 12 }, refreshed_at: @now)
    end

    test "staff read one row per account and signal, with the facts as a sentence and a link by token" do
      sign_in(accounts_players(:moderator))

      get back_office_market_signals_path(locale: :en)

      assert_response :success
      assert_select "h1", "Alt-account signals"
      assert_select "tr[data-signal]", 2
      assert_select "tr[data-signal=near_maximum_opening]", /Opened 120 capsules or more a day on 4 of the last 7 days, up to 130 in one day/
      assert_select "tr[data-signal=one_way_trades]" do
        assert_select "td", /Copies given: 48, received: 12/
        assert_select "a[href='/en/back-office/players?player=#{@alice.token}']"
        assert_select "a[href='/en/back-office/players?player=#{@bob.token}']"
      end
      assert_select "[style]", false
    end

    test "staff read the tied accounts with the signal and its facts" do
      sign_in(accounts_players(:moderator))

      get back_office_market_signals_path(locale: :en)

      assert_select "h2", "Tied accounts"
      assert_select "tr[data-tie]", 1
      assert_select "tr[data-tie=one_way_trades]" do
        assert_select "td", "Repeated one-way trades"
        assert_select "td", /Trades between the two accounts in the last 7 days where one gave far more than it got: 12/
        assert_select "a[href='/en/back-office/players?player=#{@alice.token}']"
        assert_select "a[href='/en/back-office/players?player=#{@bob.token}']"
      end
    end

    test "staff read a direct sale to a tied account's order and an Archive purchase of a tied deposit with their facts" do
      Game::Market::AltSignal.create!(account: @alice, signal: "order_sale_to_tied_buyer", other_account: @bob,
        facts: { "card" => "1984", "season" => 1, "price" => 1_500 }, refreshed_at: @now)
      Game::Market::AltSignal.create!(account: @bob, signal: "archive_purchase_of_tied_deposit", other_account: @alice,
        facts: { "card" => "portal", "season" => 2, "price" => 500, "deposited" => 3, "deposited_on" => "2026-11-02" }, refreshed_at: @now)
      sign_in(accounts_players(:moderator))

      get back_office_market_signals_path(locale: :en)

      assert_select "tr[data-signal=order_sale_to_tied_buyer][data-account-token='#{@alice.token}']" do
        assert_select "td", "Direct sale to a tied account's order"
        assert_select "td", /Sold 1984 \(season 1\) to the buy order of the other account, which another signal ties to it, for 1,500 PiCoins/
        assert_select "a[href='/en/back-office/players?player=#{@bob.token}']"
      end
      assert_select "tr[data-signal=archive_purchase_of_tied_deposit][data-account-token='#{@bob.token}']" do
        assert_select "td", "Archive purchase of a tied account's deposit"
        assert_select "td", /Bought portal \(season 2\) from the Archives for 500 PiCoins.*Copies entrusted: 3, last on 2026-11-02/
        assert_select "a[href='/en/back-office/players?player=#{@alice.token}']"
      end

      get back_office_market_signals_path(locale: :fr)

      assert_select "tr[data-signal=archive_purchase_of_tied_deposit] td", "Achat aux Archives du dépôt d'un compte lié"
    end

    test "with signals but no tie the page says no signal ties two accounts, in French too" do
      Game::Market::TiedAccount.delete_all
      sign_in(accounts_players(:moderator))

      get back_office_market_signals_path(locale: :fr)

      assert_select "[data-ties-empty]", "Aucun signal ne lie deux comptes."
    end

    test "with no signal the page says so, in French too" do
      Game::Market::AltSignal.delete_all
      sign_in(accounts_players(:moderator))

      get back_office_market_signals_path(locale: :fr)

      assert_select "[data-signals-empty]", "Aucun compte ne correspond à un signal."
    end

    test "the navigation leads to the signals page" do
      sign_in(accounts_players(:moderator))

      get back_office_market_health_path(locale: :en)

      assert_select "nav.market-navigation a[href='/en/back-office/market/signals']"
    end

    test "the page writes nothing" do
      sign_in(accounts_players(:moderator))

      assert_no_difference -> { Game::Market::AltSignal.count + Game::Market::TiedAccount.count + Accounts::Player.where.not(banned_at: nil).count } do
        get back_office_market_signals_path(locale: :en)
      end
    end

    test "the players page filtered by a token shows that one row, where the ban applies" do
      sign_in(accounts_players(:moderator))

      get back_office_players_path(locale: :en, player: @alice.token)

      assert_select "tr[data-player-token]", 1
      assert_select "tr[data-player-token='#{@alice.token}']"
      assert_select "[data-player-only]"
    end

    test "a player and a visitor see an unknown address" do
      get back_office_market_signals_path(locale: :en)
      assert_unknown_address

      sign_in(accounts_players(:player))
      get back_office_market_signals_path(locale: :en)
      assert_unknown_address
    end
  end
end
