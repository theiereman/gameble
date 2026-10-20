require "test_helper"

class LandingPolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the landing" do
      player = role == :visitor ? nil : accounts_players(role)

      assert LandingPolicy.new(player, :landing).show?
    end

    test "a #{role} may do nothing else on the landing" do
      player = role == :visitor ? nil : accounts_players(role)
      policy = LandingPolicy.new(player, :landing)

      %i[index? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
    end
  end
end
