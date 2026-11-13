require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"

class Market::BalanceChipTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Holdings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
    Game::Market::Settings.delete_all
  end

  def open_first_time!(**overrides) = open_market!(first_opened_at: Time.current, **overrides)

  def give(available:, committed:)
    settings = Game::Market::CurrentSettings.call
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: @player.id, kind: :mint, available_delta: available + committed,
      committed_delta: 0, settings_id: settings.id) ])
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: @player.id, kind: :hold, available_delta: -committed,
      committed_delta: committed, settings_id: settings.id) ])
  end

  test "after the first opening a page has the bar chip and Confier the header chip, with compact and exact amounts" do
    open_first_time!
    give(available: 31_599, committed: 12_000)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select ".top-bar__end a.balance-link[href=?]", market_path(locale: :en), 1 do
      assert_select ".visually-hidden", "Your balance, to the market:"
      assert_select ".balance-chip--bar .balance-chip__available .picoin-amount__figure", "31.5k"
      assert_select ".balance-chip--bar .balance-chip__available[aria-label=?]", "31,599 PiCoins"
    end
    assert_select ".market-entrust__header .balance-chip--header[role=group][aria-label=Balance]", 1 do
      assert_select ".balance-chip__committed [aria-hidden=true]", /12k committed/
      assert_select ".balance-chip__committed .visually-hidden", /12,000 committed/
    end
    assert_select ".balance-chip [style]", false
  end

  test "another page shows only the bar chip" do
    open_first_time!
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".balance-chip--bar", 1
    assert_select ".balance-chip--header", false
  end

  test "a market closed after its first opening still shows the chip" do
    open_first_time!
    close_market!(first_opened_at: Time.current)
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".balance-chip--bar", 1
  end

  test "before the first opening there is no chip and the wallet is not read" do
    open_market!
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".balance-chip", false
  end

  test "a visitor has no chip" do
    open_first_time!

    get home_path(locale: :en)

    assert_select ".balance-chip", false
  end

  test "a GET writes no wallet row" do
    open_first_time!
    sign_in(@player)

    assert_no_difference -> { Game::Market::Wallet.count } do
      get home_path(locale: :en)
    end
    assert_select ".balance-chip__available .picoin-amount__figure", "0"
  end

  test "the answer to an entrustment shows the new available amount" do
    settings = open_first_time!
    hold(@player, @rare.id, 1)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: settings.token, selection: "#{@rare.card.slug}:#{@rare.season.number}=1" }

    assert_response :success
    assert_select ".market-entrust__header .balance-chip--header .balance-chip__available[aria-label=?]", "5,000 PiCoins"
  end
end
