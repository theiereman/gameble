require "test_helper"

class ClerkSessionPolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may post a Clerk session to the callback" do
      player = role == :visitor ? nil : accounts_players(role)

      assert ClerkSessionPolicy.new(player, :clerk_session).create?
    end
  end
end
