require "test_helper"

class Market::MySalePolicyTest < ActiveSupport::TestCase
  def policy_for(role) = Market::MySalePolicy.new(role == :visitor ? nil : accounts_players(role), %i[market my_sale])

  test "a visitor may not read MES VENTES" do
    assert_not policy_for(:visitor).show?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read MES VENTES" do
      assert policy_for(role).show?
    end
  end
end
