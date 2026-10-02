require "test_helper"
require_relative "../support/game_packs"

class PackPolicyTest < ActiveSupport::TestCase
  include GamePacks

  def policy_for(role, record = :pack)
    PackPolicy.new(role == :visitor ? nil : accounts_players(role), record)
  end

  test "a visitor may not open a pack" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open a pack" do
      assert policy_for(role).create?
    end
  end

  test "only the owner may read an opened pack" do
    opened = create_pack(accounts_players(:player), opened_at: 1.minute.ago)

    assert policy_for(:player, opened).show?
    assert_not policy_for(:moderator, opened).show?
    assert_not policy_for(:administrator, opened).show?
    assert_not policy_for(:visitor, opened).show?
  end

  test "an unopened pack may not be read, even by its owner" do
    assert_not policy_for(:player, create_pack(accounts_players(:player))).show?
  end
end
