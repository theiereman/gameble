require "test_helper"

class BoosterPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    BoosterPolicy.new(role == :visitor ? nil : accounts_players(role), :booster)
  end

  test "a visitor may not open capsules" do
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open capsules" do
      assert policy_for(role).show?
    end
  end
end
