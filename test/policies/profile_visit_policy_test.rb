require "test_helper"

class ProfileVisitPolicyTest < ActiveSupport::TestCase
  test "a visitor may not record a profile visit" do
    assert_not ProfileVisitPolicy.new(nil, :profile_visit).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may" do
      assert ProfileVisitPolicy.new(accounts_players(role), :profile_visit).create?
    end
  end
end
