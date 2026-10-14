require "test_helper"

class AchievementPolicyTest < ActiveSupport::TestCase
  test "a visitor may not read the achievements screen" do
    assert_not AchievementPolicy.new(nil, :achievement).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read the achievements screen" do
      assert AchievementPolicy.new(accounts_players(role), :achievement).show?
    end
  end
end
