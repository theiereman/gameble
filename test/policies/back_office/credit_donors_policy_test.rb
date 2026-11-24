require "test_helper"

module BackOffice
  class CreditDonorsPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      CreditDonorsPolicy.new(role == :visitor ? nil : accounts_players(role), :credit_donors)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not manage the credits donors" do
        assert_not policy_for(role).index?
        assert_not policy_for(role).create?
        assert_not policy_for(role).destroy?
      end
    end

    test "an administrator manages the credits donors" do
      assert_predicate policy_for(:administrator), :index?
      assert_predicate policy_for(:administrator), :create?
      assert_predicate policy_for(:administrator), :destroy?
    end
  end
end
