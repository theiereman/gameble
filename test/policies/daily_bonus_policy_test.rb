require "test_helper"

class DailyBonusPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    DailyBonusPolicy.new(role == :visitor ? nil : accounts_players(role), :daily_bonus)
  end

  test "a visitor may not collect the daily bonus" do
    assert_not policy_for(:visitor).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may collect the daily bonus" do
      assert policy_for(role).create?
    end
  end
end
