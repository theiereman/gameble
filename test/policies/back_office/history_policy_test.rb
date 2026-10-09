require "test_helper"

module BackOffice
  class HistoryPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      HistoryPolicy.new(role == :visitor ? nil : accounts_players(role), :history)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may not read the moderation history" do
        assert_not policy_for(role).index?
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} reads the moderation history" do
        assert_predicate policy_for(role), :index?
      end
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the moderation history" do
        policy = policy_for(role)

        %i[show? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
