require "test_helper"

class WelcomePolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    WelcomePolicy.new(role == :visitor ? nil : accounts_players(role), :welcome)
  end

  test "a visitor may not close a welcome" do
    assert_not policy_for(:visitor).destroy?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may close their welcome" do
      assert policy_for(role).destroy?
    end
  end
end
