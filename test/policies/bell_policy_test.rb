require "test_helper"

class BellPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    BellPolicy.new(role == :visitor ? nil : accounts_players(role), :bell)
  end

  test "a visitor has no bell" do
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} reads their bell" do
      assert policy_for(role).show?
    end
  end
end
