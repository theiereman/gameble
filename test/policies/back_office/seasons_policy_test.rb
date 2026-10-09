require "test_helper"

module BackOffice
  class SeasonsPolicyTest < ActiveSupport::TestCase
    ACTIONS = %i[index? show? publish?].freeze

    def policy_for(role)
      SeasonsPolicy.new(role == :visitor ? nil : accounts_players(role), :seasons)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not see, read or publish the seasons" do
        policy = policy_for(role)

        ACTIONS.each { |action| assert_not policy.public_send(action), action }
      end
    end

    test "an administrator may see, read and publish the seasons" do
      policy = policy_for(:administrator)

      ACTIONS.each { |action| assert policy.public_send(action), action }
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the seasons" do
        policy = policy_for(role)

        %i[create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
