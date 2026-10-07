require "test_helper"

class TradePolicyTest < ActiveSupport::TestCase
  ACTIONS = %i[index? show? new? create? counter? accept? decline? cancel?].freeze

  test "a visitor may neither read nor answer trades" do
    ACTIONS.each { |action| assert_not TradePolicy.new(nil, :trade).public_send(action), action }
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read and answer their trades" do
      ACTIONS.each { |action| assert TradePolicy.new(accounts_players(role), :trade).public_send(action), action }
    end
  end
end
