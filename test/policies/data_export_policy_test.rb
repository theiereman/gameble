require "test_helper"

class DataExportPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    DataExportPolicy.new(role == :visitor ? nil : accounts_players(role), :data_export)
  end

  test "a visitor may not export" do
    assert_not policy_for(:visitor).create?
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may export their own data" do
      assert policy_for(role).create?
      assert policy_for(role).show?
    end
  end

  test "nothing else is allowed" do
    assert_not policy_for(:player).destroy?
  end
end
