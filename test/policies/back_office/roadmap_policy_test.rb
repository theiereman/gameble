require "test_helper"

module BackOffice
  class RoadmapPolicyTest < ActiveSupport::TestCase
    ACTIONS = %i[index? new? create? edit? update? move? destroy?].freeze

    def policy_for(role)
      RoadmapPolicy.new(role == :visitor ? nil : accounts_players(role), :roadmap)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may neither read nor change the roadmap" do
        policy = policy_for(role)

        ACTIONS.each { |action| assert_not policy.public_send(action), action }
      end
    end

    test "an administrator reads the roadmap, edits and moves its milestones, and adds, edits, moves and deletes its stories" do
      policy = policy_for(:administrator)

      ACTIONS.each { |action| assert policy.public_send(action), action }
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may not show a single roadmap entry" do
        assert_not policy_for(role).show?
      end
    end
  end
end
