require "test_helper"

module BackOffice
  class BansPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      BansPolicy.new(role == :visitor ? nil : accounts_players(role), :bans)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may neither read the banned players nor ban nor lift a ban" do
        policy = policy_for(role)

        %i[index? create? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} reads the banned players, bans and lifts a ban" do
        policy = policy_for(role)

        %i[index? create? destroy?].each { |action| assert policy.public_send(action), action }
      end
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the bans" do
        policy = policy_for(role)

        %i[show? new? update? edit?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
