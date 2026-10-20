require "test_helper"

class ShowcasePolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    ShowcasePolicy.new(role == :visitor ? nil : accounts_players(role), :showcase)
  end

  test "a visitor may not change a showcase" do
    assert_not policy_for(:visitor).create?
    assert_not policy_for(:visitor).update?
    assert_not policy_for(:visitor).destroy?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may add to, reorder and remove from their showcase" do
      assert policy_for(role).create?
      assert policy_for(role).update?
      assert policy_for(role).destroy?
    end
  end
end
