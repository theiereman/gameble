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
end
