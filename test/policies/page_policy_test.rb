require "test_helper"

class PagePolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read pages" do
      player = role == :visitor ? nil : accounts_players(role)

      assert PagePolicy.new(player, :page).show?
    end

    test "a #{role} may do nothing else on pages" do
      player = role == :visitor ? nil : accounts_players(role)
      policy = PagePolicy.new(player, :page)

      %i[index? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
    end
  end
end
