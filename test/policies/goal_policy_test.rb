require "test_helper"

class GoalPolicyTest < ActiveSupport::TestCase
  test "a visitor may not mark or unmark a goal" do
    %i[create? destroy?].each { assert_not GoalPolicy.new(nil, :goal).public_send(it) }
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may mark and unmark their goals" do
      %i[create? destroy?].each { assert GoalPolicy.new(accounts_players(role), :goal).public_send(it) }
    end
  end
end
