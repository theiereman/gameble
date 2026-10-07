require "test_helper"

class AccountPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    AccountPolicy.new(role == :visitor ? nil : accounts_players(role), :account)
  end

  test "a visitor may not delete an account" do
    assert_not policy_for(:visitor).destroy?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may delete their own account" do
      assert policy_for(role).destroy?
    end
  end

  test "nothing else is allowed" do
    assert_not policy_for(:player).show?
    assert_not policy_for(:player).update?
  end
end
