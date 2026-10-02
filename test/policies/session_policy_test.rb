require "test_helper"

class SessionPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    SessionPolicy.new(role == :visitor ? nil : accounts_players(role), :session)
  end

  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may start and finish a sign-in" do
      assert policy_for(role).create?
      assert policy_for(role).failure?
    end
  end

  test "a visitor may not sign out" do
    assert_not policy_for(:visitor).destroy?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may sign out" do
      assert policy_for(role).destroy?
    end
  end
end
