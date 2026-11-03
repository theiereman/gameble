require "test_helper"

module BackOffice
  class RoadmapPolicyTest < ActiveSupport::TestCase
    ACTIONS = %i[show? update? preview?].freeze

    def policy_for(role)
      RoadmapPolicy.new(role == :visitor ? nil : accounts_players(role), :roadmap)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may neither read, save nor preview the roadmap" do
        policy = policy_for(role)

        ACTIONS.each { |action| assert_not policy.public_send(action), action }
      end
    end

    test "an administrator reads, saves and previews the roadmap" do
      policy = policy_for(:administrator)

      ACTIONS.each { |action| assert policy.public_send(action), action }
    end
  end
end
