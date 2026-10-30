require "test_helper"

class AchievementPolicyTest < ActiveSupport::TestCase
  test "a visitor may not read the achievements screen nor collect one" do
    assert_not AchievementPolicy.new(nil, :achievement).show?
    assert_not AchievementPolicy.new(nil, :achievement).collect?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read the achievements screen" do
      assert AchievementPolicy.new(accounts_players(role), :achievement).show?
      assert AchievementPolicy.new(accounts_players(role), :achievement).collect?
    end
  end
end
