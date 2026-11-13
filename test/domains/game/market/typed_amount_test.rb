require "test_helper"

class Game::Market::TypedAmountTest < ActiveSupport::TestCase
  ROWS = JSON.parse(Rails.root.join("test/fixtures/files/typed_amounts.json").read)

  test "every typed amount of the shared fixture reads the same as on the client" do
    ROWS.each do |row|
      assert_equal [ row["digits"] ], [ Game::Market::TypedAmount.digits(row["text"]) ], row.inspect
    end
  end

  test "a price is a whole number from one to the bigint maximum" do
    assert_equal 8_000_000, Game::Market::TypedAmount.price("8,000,000")
    assert_equal 1, Game::Market::TypedAmount.price(1)
    assert_nil Game::Market::TypedAmount.price("0")
    assert_nil Game::Market::TypedAmount.price(nil)
    assert_nil Game::Market::TypedAmount.price((Game::Market::TypedAmount::MAX + 1).to_s)
  end

  test "a filter bound is a string under the filter ceiling" do
    assert_equal 5_000, Game::Market::TypedAmount.filter_bound("5 000")
    assert_equal 0, Game::Market::TypedAmount.filter_bound("0")
    assert_nil Game::Market::TypedAmount.filter_bound(5_000)
    assert_nil Game::Market::TypedAmount.filter_bound("1" * 14)
  end
end
