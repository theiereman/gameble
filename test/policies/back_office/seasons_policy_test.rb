require "test_helper"

module BackOffice
  class SeasonsPolicyTest < ActiveSupport::TestCase
    ACTIONS = %i[index? publish?].freeze

    def policy_for(role)
      SeasonsPolicy.new(role == :visitor ? nil : accounts_players(role), :seasons)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not see or publish the seasons" do
        policy = policy_for(role)

        ACTIONS.each { |action| assert_not policy.public_send(action), action }
      end
    end

    test "an administrator may see and publish the seasons" do
      policy = policy_for(:administrator)

      ACTIONS.each { |action| assert policy.public_send(action), action }
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the seasons" do
        policy = policy_for(role)

        %i[show? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
