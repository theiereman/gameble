require "test_helper"

class Market::MyBidPolicyTest < ActiveSupport::TestCase
  def policy_for(role) = Market::MyBidPolicy.new(role == :visitor ? nil : accounts_players(role), %i[market my_bid])

  test "a visitor may not read MES ENCHÈRES" do
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read MES ENCHÈRES" do
      assert policy_for(role).show?
    end
  end
end
