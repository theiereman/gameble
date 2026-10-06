require "test_helper"

class CollectionSeenPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    CollectionSeenPolicy.new(role == :visitor ? nil : accounts_players(role), :collection_seen)
  end

  test "a visitor may not mark a collection seen" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may mark their collection seen" do
      assert policy_for(role).create?
    end
  end
end
