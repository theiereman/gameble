require "test_helper"

class PagePolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may read pages" do
      player = role == :visitor ? nil : accounts_players(role)

      assert PagePolicy.new(player, :page).show?
    end
  end
end
