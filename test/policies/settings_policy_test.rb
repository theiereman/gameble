require "test_helper"

class SettingsPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    SettingsPolicy.new(role == :visitor ? nil : accounts_players(role), :settings)
  end

  test "a visitor may neither read nor change settings" do
    assert_not policy_for(:visitor).show?
    assert_not policy_for(:visitor).update?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read and change their settings" do
      assert policy_for(role).show?
      assert policy_for(role).update?
    end
  end

  test "nothing else is allowed" do
    assert_not policy_for(:player).destroy?
    assert_not policy_for(:player).create?
  end
end
