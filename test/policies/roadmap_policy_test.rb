require "test_helper"

class RoadmapPolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the roadmap" do
      player = role == :visitor ? nil : accounts_players(role)

      assert RoadmapPolicy.new(player, :roadmap).show?
    end

    test "a #{role} may do nothing else on the roadmap" do
      player = role == :visitor ? nil : accounts_players(role)
      policy = RoadmapPolicy.new(player, :roadmap)

      %i[index? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
    end
  end
end
