require "test_helper"
require_relative "../../../support/market"

class Game::Market::MarketStateTest < ActiveSupport::TestCase
  include MarketSettings

  setup { Game::Market::Settings.delete_all }

  test "no settings means closed and never opened" do
    state = Game::Market::MarketState.call

    assert_not state.open?
    assert_not state.first_opened?
    assert_nil state.first_opened_at
  end

  test "a closed version that was never opened" do
    open_market!(open: false)

    assert_not Game::Market::MarketState.call.open?
    assert_not Game::Market::MarketState.call.first_opened?
  end

  test "an open version reads open and first opened" do
    moment = Time.zone.parse("2026-11-01 10:00")
    open_market!(first_opened_at: moment)

    state = Game::Market::MarketState.call

    assert state.open?
    assert state.first_opened?
    assert_equal moment, state.first_opened_at
  end

  test "a closed version after an opening is suspended, not never opened" do
    open_market!(first_opened_at: 1.day.ago)
    close_market!(first_opened_at: 1.day.ago)

    state = Game::Market::MarketState.call

    assert_not state.open?
    assert state.first_opened?
  end

  test "it reads the settings it is given" do
    settings = Game::Market::Settings.new(open: true, first_opened_at: nil)

    assert Game::Market::MarketState.call(settings).open?
  end

  test "suspended is a closed market after a first opening, and nothing else" do
    assert_not Game::Market::MarketState.call.suspended?

    open_market!(open: false)
    assert_not Game::Market::MarketState.call.suspended?

    open_market!(first_opened_at: 1.day.ago)
    assert_not Game::Market::MarketState.call.suspended?

    close_market!(first_opened_at: 1.day.ago)
    assert Game::Market::MarketState.call.suspended?
  end
end
