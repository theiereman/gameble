require "test_helper"

class BellReadPolicyTest < ActiveSupport::TestCase
  test "a visitor may not mark bell lines read" do
    assert_not BellReadPolicy.new(nil, :bell_read).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may" do
      assert BellReadPolicy.new(accounts_players(role), :bell_read).create?
    end
  end
end
