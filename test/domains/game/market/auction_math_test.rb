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

  test "the increment is the percentage rounded up to a whole PiCoin" do
    assert_equal 10, Game::Market::AuctionMath.increment(200, 500)
    assert_equal 13, Game::Market::AuctionMath.increment(250, 500)
    assert_equal 14, Game::Market::AuctionMath.increment(263, 500)
    assert_equal 15, Game::Market::AuctionMath.increment(300, 500)
    assert_equal 1, Game::Market::AuctionMath.increment(1, 500)
  end

  def displayed(highest:, second:, start: 200) = Game::Market::AuctionMath.displayed_price(highest:, second:, starting_price: start, basis_points: 500)

  test "the displayed price is the starting price with one bidder" do
    assert_equal 200, displayed(highest: 300, second: nil)
  end

  test "the displayed price is the second maximum plus an increment, capped at the highest" do
    assert_equal 263, displayed(highest: 300, second: 250)
    assert_equal 315, displayed(highest: 400, second: 300)
    assert_equal 300, displayed(highest: 300, second: 300)
    assert_equal 300, displayed(highest: 300, second: 295)
  end

  def minimum(price:) = Game::Market::AuctionMath.minimum_bid(price:, starting_price: 200, basis_points: 500)

  test "the minimum bid is the starting price without a leader" do
    assert_equal 200, minimum(price: nil)
  end

  test "the minimum bid is the price plus an increment" do
    assert_equal 210, minimum(price: 200)
    assert_equal 277, minimum(price: 263)
    assert_equal 520, minimum(price: 495)
  end

  test "a leader's raise only has to be above their own maximum" do
    assert_equal 301, Game::Market::AuctionMath.raise_minimum(300)
  end

  test "the worked example reads 200, 263 and 315" do
    assert_equal 200, displayed(highest: 300, second: nil)
    assert_equal 263, displayed(highest: 300, second: 250)
    assert_equal 315, displayed(highest: 400, second: 300)
  end
end
