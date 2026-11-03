require "test_helper"

class RoadmapPolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the roadmap" do
      player = role == :visitor ? nil : accounts_players(role)

      assert RoadmapPolicy.new(player, :roadmap).show?
    end
  end
end
