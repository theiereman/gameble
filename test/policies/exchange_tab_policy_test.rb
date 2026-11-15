require "test_helper"

class ExchangeTabPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    ExchangeTabPolicy.new(role == :visitor ? nil : accounts_players(role), :exchange_tab)
  end

  test "a visitor may not keep a sub-tab" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may keep the sub-tab they use" do
      assert policy_for(role).create?
    end
  end
end
