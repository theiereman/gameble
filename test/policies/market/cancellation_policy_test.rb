require "test_helper"

class Market::CancellationPolicyTest < ActiveSupport::TestCase
  Detail = Struct.new(:seller)

  def policy_for(player, seller) = Market::CancellationPolicy.new(player, Detail.new(seller))

  test "a visitor may not cancel" do
    assert_not policy_for(nil, accounts_players(:player)).create?
  end

  test "another player may not cancel, a moderator and an administrator included" do
    %i[moderator administrator].each do |role|
      assert_not policy_for(accounts_players(role), accounts_players(:player)).create?
    end
  end

  test "the seller may cancel" do
    seller = accounts_players(:player)

    assert policy_for(seller, seller).create?
  end
end
