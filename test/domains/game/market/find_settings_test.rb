require "test_helper"
require_relative "../../../support/market"

class Game::Market::FindSettingsTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    Game::Market::Settings.delete_all
    @older = open_market!
    @current = open_market!
  end

  test "it finds the version with that token, current or older" do
    assert_equal @older, Game::Market::FindSettings.call(@older.token)
    assert_equal @current, Game::Market::FindSettings.call(@current.token)
  end

  test "an unknown, blank or missing token finds nothing" do
    assert_nil Game::Market::FindSettings.call("nope")
    assert_nil Game::Market::FindSettings.call("")
    assert_nil Game::Market::FindSettings.call(nil)
  end
end
