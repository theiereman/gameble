require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_listings"

class Game::CheckMarketHealthJobTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!
    @seller = accounts_players(:player)
    @card = catalog_card_seasons(:common_card_one)
  end

  test "an auction due for four minutes reports nothing" do
    listing!(seller: @seller, card_season: @card, ends_at: 4.minutes.ago)

    assert_no_error_reported { Game::CheckMarketHealthJob.perform_now }
  end

  test "no due auction reports nothing" do
    assert_no_error_reported { Game::CheckMarketHealthJob.perform_now }
  end

  test "an auction due for six minutes reports once with its age" do
    listing!(seller: @seller, card_season: @card, ends_at: 6.minutes.ago)

    report = assert_error_reported(Game::CheckMarketHealthJob::StaleClose) { Game::CheckMarketHealthJob.perform_now }

    assert_in_delta 360, report.context[:age_seconds], 5
  end
end
