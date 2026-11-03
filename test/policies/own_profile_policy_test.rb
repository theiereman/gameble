require "test_helper"

class OwnProfilePolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    OwnProfilePolicy.new(role == :visitor ? nil : accounts_players(role), :own_profile)
  end

  test "a visitor has no own profile to read" do
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} reads their own profile" do
      assert policy_for(role).show?
    end
  end

  test "nothing else is allowed" do
    assert_not policy_for(:player).update?
    assert_not policy_for(:player).destroy?
  end
end
