require "test_helper"

class Game::Market::AuctionMathTest < ActiveSupport::TestCase
  test "the commission is the integer floor of the price at the basis points" do
    assert_equal 0, Game::Market::AuctionMath.commission(1_299, 0)
    assert_equal 32, Game::Market::AuctionMath.commission(1_300, 250)
    assert_equal 130, Game::Market::AuctionMath.commission(1_300, 1_000)
    assert_equal 129, Game::Market::AuctionMath.commission(1_299, 1_000)
    assert_equal 325, Game::Market::AuctionMath.commission(1_300, 2_500)
    assert_equal 0, Game::Market::AuctionMath.commission(3, 250)
  end

  test "a whole percent gives the same integer as the percent formula" do
    [ 1, 99, 1_234, 7_000_000 ].each do |price|
      assert_equal price * 10 / 100, Game::Market::AuctionMath.commission(price, 1_000)
    end
  end

  test "every row of the shared fixture gives the same commission and amount received as on the client" do
    JSON.parse(file_fixture("listing_amounts.json").read).each do |row|
      commission = Game::Market::AuctionMath.commission(row["price"].to_i, row["basisPoints"])

      assert_equal row["commission"].to_i, commission, row.inspect
      assert_equal row["received"].to_i, row["price"].to_i - commission, row.inspect
    end
  end

  test "the increment is the percentage rounded up to the next hundred" do
    assert_equal 1_000, Game::Market::AuctionMath.increment(20_000, 500)
    assert_equal 1_300, Game::Market::AuctionMath.increment(25_000, 500)
    assert_equal 1_400, Game::Market::AuctionMath.increment(26_300, 500)
    assert_equal 1_500, Game::Market::AuctionMath.increment(30_000, 500)
    assert_equal 100, Game::Market::AuctionMath.increment(1, 500)
  end

  def displayed(highest:, second:, start: 20_000) = Game::Market::AuctionMath.displayed_price(highest:, second:, starting_price: start, basis_points: 500)

  test "the displayed price is the starting price with one bidder" do
    assert_equal 20_000, displayed(highest: 30_000, second: nil)
  end

  test "the displayed price is the second maximum plus an increment, capped at the highest" do
    assert_equal 26_300, displayed(highest: 30_000, second: 25_000)
    assert_equal 31_500, displayed(highest: 40_000, second: 30_000)
    assert_equal 30_000, displayed(highest: 30_000, second: 30_000)
    assert_equal 30_000, displayed(highest: 30_000, second: 29_500)
  end

  def minimum(price:, buy_now_price: nil) = Game::Market::AuctionMath.minimum_bid(price:, starting_price: 20_000, buy_now_price:, basis_points: 500)

  test "the minimum bid is the starting price without a leader" do
    assert_equal 20_000, minimum(price: nil)
    assert_equal 20_000, minimum(price: nil, buy_now_price: 50_000)
  end

  test "the minimum bid is the price plus an increment, capped at the buy-now price" do
    assert_equal 21_000, minimum(price: 20_000)
    assert_equal 27_700, minimum(price: 26_300)
    assert_equal 50_000, minimum(price: 49_500, buy_now_price: 50_000)
    assert_equal 21_000, minimum(price: 20_000, buy_now_price: 50_000)
  end

  test "a leader's raise only has to be above their own maximum" do
    assert_equal 30_001, Game::Market::AuctionMath.raise_minimum(30_000)
  end

  test "the worked example reads 20,000, 26,300 and 31,500" do
    assert_equal 20_000, displayed(highest: 30_000, second: nil)
    assert_equal 26_300, displayed(highest: 30_000, second: 25_000)
    assert_equal 31_500, displayed(highest: 40_000, second: 30_000)
  end
end
