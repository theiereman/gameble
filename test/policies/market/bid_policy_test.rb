require "test_helper"

class Market::BidPolicyTest < ActiveSupport::TestCase
  def policy_for(role) = Market::BidPolicy.new(role == :visitor ? nil : accounts_players(role), %i[market bid])

  test "a visitor may not bid" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may bid" do
      assert policy_for(role).create?
    end
  end
end
