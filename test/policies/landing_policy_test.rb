require "test_helper"

class LandingPolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the landing" do
      player = role == :visitor ? nil : accounts_players(role)

      assert LandingPolicy.new(player, :landing).show?
    end
  end
end
