require "test_helper"

class ExchangePolicyTest < ActiveSupport::TestCase
  def policy_for(role)
    ExchangePolicy.new(role == :visitor ? nil : accounts_players(role), :exchange)
  end

  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may follow the trades tab" do
      assert policy_for(role).show?
    end
  end
end
