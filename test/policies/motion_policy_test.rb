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
end
