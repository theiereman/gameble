require "test_helper"

module BackOffice
  class CardsPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      CardsPolicy.new(role == :visitor ? nil : accounts_players(role), :cards)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not see the card preview" do
        assert_not policy_for(role).index?
      end
    end

    test "an administrator may see the card preview" do
      assert policy_for(:administrator).index?
    end

    [ :visitor, :player, :moderator, :administrator ].each do |role|
      test "a #{role} may do nothing else with the cards" do
        policy = policy_for(role)

        %i[show? create? new? update? edit? destroy?].each { |action| assert_not policy.public_send(action), action }
      end
    end
  end
end
