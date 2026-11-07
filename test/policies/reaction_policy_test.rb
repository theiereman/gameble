require "test_helper"

class ReactionPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    ReactionPolicy.new(role == :visitor ? nil : accounts_players(role), :reaction)
  end

  test "a visitor sees the counters and may not react" do
    assert_predicate policy_for(:visitor), :show?
    assert_not policy_for(:visitor).create?
    assert_not policy_for(:visitor).destroy?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may react and take a reaction back" do
      assert_predicate policy_for(role), :show?
      assert_predicate policy_for(role), :create?
      assert_predicate policy_for(role), :destroy?
    end
  end
end
