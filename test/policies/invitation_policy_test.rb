require "test_helper"

class InvitationPolicyTest < ActiveSupport::TestCase
  test "a visitor may not send, accept, ignore or cancel an invitation" do
    policy = InvitationPolicy.new(nil, :invitation)

    assert_not policy.create?
    assert_not policy.accept?
    assert_not policy.ignore?
    assert_not policy.cancel?
  end

  test "a player may send, accept, ignore and cancel" do
    policy = InvitationPolicy.new(accounts_players(:player), :invitation)

    assert policy.create?
    assert policy.accept?
    assert policy.ignore?
    assert policy.cancel?
  end

  test "anyone opens an invite link, only a player sends from it" do
    assert InviteLinkPolicy.new(nil, :invite_link).show?
    assert_not InviteLinkPolicy.new(nil, :invite_link).create?
    assert InviteLinkPolicy.new(accounts_players(:player), :invite_link).create?
  end
end
