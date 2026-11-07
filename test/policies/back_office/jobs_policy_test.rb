require "test_helper"

module BackOffice
  class JobsPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      JobsPolicy.new(role == :visitor ? nil : accounts_players(role), :jobs)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not open the job queue" do
        assert_not policy_for(role).show?
      end
    end

    test "an administrator may open the job queue" do
      assert policy_for(:administrator).show?
    end
  end
end
