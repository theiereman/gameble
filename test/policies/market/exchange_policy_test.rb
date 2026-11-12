require "test_helper"

class Market::ExchangePolicyTest < ActiveSupport::TestCase
  def policy_for(role) = Market::ExchangePolicy.new(role == :visitor ? nil : accounts_players(role), %i[market exchange])

  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may ask for the exchange, which then decides what it shows" do
      assert policy_for(role).show?
    end
  end
end
