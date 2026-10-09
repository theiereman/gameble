require "test_helper"

module BackOffice
  class PlayersPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      PlayersPolicy.new(role == :visitor ? nil : accounts_players(role), :players)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may not read the players" do
        assert_not policy_for(role).index?
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} reads the players" do
        assert_predicate policy_for(role), :index?
      end
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the players" do
        policy = policy_for(role)

        %i[show? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
