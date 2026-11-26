require "test_helper"

module BackOffice
  class SupportersPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      SupportersPolicy.new(role == :visitor ? nil : accounts_players(role), :supporters)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not mark a supporter" do
        assert_not policy_for(role).create?
        assert_not policy_for(role).destroy?
      end
    end

    test "an administrator marks a supporter" do
      assert_predicate policy_for(:administrator), :create?
      assert_predicate policy_for(:administrator), :destroy?
    end
  end
end
