require "test_helper"

class GoalRewardPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    GoalRewardPolicy.new(role == :visitor ? nil : accounts_players(role), :goal_reward)
  end

  test "a visitor may not claim a weekly goal reward" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may claim a weekly goal reward" do
      assert policy_for(role).create?
    end
  end
end
