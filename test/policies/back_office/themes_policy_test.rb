require "test_helper"

module BackOffice
  class ThemesPolicyTest < ActiveSupport::TestCase
    ACTIONS = %i[index? create? update? attach? dismiss?].freeze

    def policy_for(role)
      ThemesPolicy.new(role == :visitor ? nil : accounts_players(role), :themes)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may do nothing with the themes" do
        policy = policy_for(role)

        ACTIONS.each { |action| assert_not policy.public_send(action), action }
      end
    end

    test "an administrator may curate the themes" do
      policy = policy_for(:administrator)

      ACTIONS.each { |action| assert policy.public_send(action), action }
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the themes" do
        policy = policy_for(role)

        %i[show? new? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
