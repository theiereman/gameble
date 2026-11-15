require "test_helper"

class DuelPolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    DuelPolicy.new(role == :visitor ? nil : accounts_players(role), :duel)
  end

  test "a visitor may not open the Duels screen" do
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the Duels screen" do
      assert policy_for(role).show?
    end
  end
end
