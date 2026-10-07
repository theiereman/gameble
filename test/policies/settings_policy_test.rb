require "test_helper"

class SettingsPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    SettingsPolicy.new(role == :visitor ? nil : accounts_players(role), :settings)
  end

  test "a visitor may neither read nor change settings" do
    assert_not policy_for(:visitor).show?
    assert_not policy_for(:visitor).update?
    assert_not policy_for(:visitor).visibility?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read and change their settings" do
      assert policy_for(role).show?
      assert policy_for(role).update?
      assert policy_for(role).visibility?
    end
  end

  test "nothing else is allowed" do
    assert_not policy_for(:player).destroy?
    assert_not policy_for(:player).create?
  end
end
