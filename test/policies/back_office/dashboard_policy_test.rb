require "test_helper"

module BackOffice
  class DashboardPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      DashboardPolicy.new(role == :visitor ? nil : accounts_players(role), :dashboard)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may not open the back-office" do
        assert_not policy_for(role).show?
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} may open the back-office" do
        assert policy_for(role).show?
      end
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else in the back-office" do
        policy = policy_for(role)

        %i[index? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
