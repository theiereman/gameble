require "test_helper"

class AchievementClaimPolicyTest < ActiveSupport::TestCase
  test "a visitor may not claim an achievement" do
    assert_not AchievementClaimPolicy.new(nil, :achievement_claim).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may claim an achievement" do
      assert AchievementClaimPolicy.new(accounts_players(role), :achievement_claim).create?
    end
  end
end
