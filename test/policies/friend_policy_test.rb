require "test_helper"

class FriendPolicyTest < ActiveSupport::TestCase
  test "a visitor may not read the friends screen" do
    assert_not FriendPolicy.new(nil, :friend).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read the friends screen" do
      assert FriendPolicy.new(accounts_players(role), :friend).show?
    end
  end
end
