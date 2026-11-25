require "test_helper"

class Market::OrderPolicyTest < ActiveSupport::TestCase
  test "a visitor may not open, place or reprice an order" do
    %i[new? create? update?].each { assert_not Market::OrderPolicy.new(nil, :order).public_send(it) }
  end

  test "a player may open, place and reprice an order" do
    %i[new? create? update?].each { assert Market::OrderPolicy.new(accounts_players(:player), :order).public_send(it) }
  end
end
