require "test_helper"

class MotionPolicyTest < ActiveSupport::TestCase
  test "a visitor may turn animations down" do
    assert MotionPolicy.new(nil, :motion).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may not, their setting does" do
      assert_not MotionPolicy.new(accounts_players(role), :motion).create?
    end
  end

  test "a visitor may do nothing else" do
    policy = MotionPolicy.new(nil, :motion)

    %i[index? show? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
  end
end
