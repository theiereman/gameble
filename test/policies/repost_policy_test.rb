require "test_helper"

class RepostPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    RepostPolicy.new(role == :visitor ? nil : accounts_players(role), :repost)
  end

  test "a visitor may not repost" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may repost" do
      assert policy_for(role).create?
    end
  end
end
