require "test_helper"

module BackOffice
  class CodeContributionsPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      CodeContributionsPolicy.new(role == :visitor ? nil : accounts_players(role), :code_contributions)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not grant the code contribution" do
        assert_not policy_for(role).create?
      end
    end

    test "an administrator grants the code contribution" do
      assert_predicate policy_for(:administrator), :create?
    end
  end
end
