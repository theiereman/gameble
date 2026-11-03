require "test_helper"

class BoosterPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    BoosterPolicy.new(role == :visitor ? nil : accounts_players(role), :booster)
  end

  test "a visitor may neither open capsules nor see what an empty reserve proposes" do
    assert_not policy_for(:visitor).show?
    assert_not policy_for(:visitor).next_steps?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open capsules and see what an empty reserve proposes" do
      assert policy_for(role).show?
      assert policy_for(role).next_steps?
    end
  end
end
