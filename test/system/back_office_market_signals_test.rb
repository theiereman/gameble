require "application_system_test_case"
require_relative "../support/alt_signal_seeds"
require_relative "../support/steam_sign_in"

class BackOfficeMarketSignalsTest < ApplicationSystemTestCase
  include AltSignalSeeds
  include SteamSignIn

  setup do
    Game::Market::AltSignal.delete_all
    Game::Pack.update_all(opened_at: nil)
    @alice = accounts_players(:player)
    @bob = accounts_players(:administrator)
    @now = Time.current.utc.beginning_of_day + 40.minutes
  end

  teardown { Game::Market::AltSignal.delete_all }

  def visit_signals_as(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit back_office_market_signals_path(locale: :en)
  end

  test "after the job runs staff see both signals with their facts and reach the account from the link" do
    (1..3).each { open_capsules!(@alice, 130, on: @now.to_date - it) }
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 2.days) }
    Game::RefreshAltSignalsJob.perform_now(now: @now)

    visit_signals_as(accounts_players(:moderator))

    assert_selector "tr[data-signal=near_maximum_opening]", text: "up to 130 in one day"
    assert_selector "tr[data-signal=one_way_trades]", text: "Copies given: 40, received: 10"
    within("tr[data-signal=near_maximum_opening]") { first("a").click }

    assert_selector "tr[data-player-token='#{@alice.token}']"
    assert_selector "tr[data-player-token]", count: 1
  end

  test "a player gets the back-office refusal" do
    visit_signals_as(accounts_players(:player))

    assert_no_selector "tr[data-signal]"
    assert_text "PAGE NOT FOUND"
  end
end
