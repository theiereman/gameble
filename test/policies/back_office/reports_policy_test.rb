require "test_helper"

module BackOffice
  class ReportsPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      ReportsPolicy.new(role == :visitor ? nil : accounts_players(role), :reports)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may neither read the queue nor class reports" do
        policy = policy_for(role)

        assert_not policy.index?
        assert_not policy.dismiss?
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} reads the queue and classes reports" do
        policy = policy_for(role)

        assert policy.index?
        assert policy.dismiss?
      end
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the reports" do
        policy = policy_for(role)

        %i[show? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
