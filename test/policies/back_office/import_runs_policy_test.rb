require "test_helper"

module BackOffice
  class ImportRunsPolicyTest < ActiveSupport::TestCase
    ACTIONS = %i[index? show? create? resume? rescore? abandon?].freeze

    def policy_for(role)
      ImportRunsPolicy.new(role == :visitor ? nil : accounts_players(role), :import_runs)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not see, start or resume an import" do
        policy = policy_for(role)

        ACTIONS.each { |action| assert_not policy.public_send(action), action }
      end
    end

    test "an administrator may see, start and resume an import" do
      policy = policy_for(:administrator)

      ACTIONS.each { |action| assert policy.public_send(action), action }
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the imports" do
        policy = policy_for(role)

        %i[new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
