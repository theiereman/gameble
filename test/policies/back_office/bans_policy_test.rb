require "test_helper"

module BackOffice
  class BansPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      BansPolicy.new(role == :visitor ? nil : accounts_players(role), :bans)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may neither ban nor unban" do
        policy = policy_for(role)

        assert_not policy.create?
        assert_not policy.destroy?
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} may ban and unban" do
        policy = policy_for(role)

        assert policy.create?
        assert policy.destroy?
      end
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the bans" do
        policy = policy_for(role)

        %i[index? show? new? update? edit?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
