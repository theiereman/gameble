require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  ACTIONS = %i[index? show? create? new? update? edit? destroy?].freeze

  def players
    { visitor: nil, player: accounts_players(:player), moderator: accounts_players(:moderator), administrator: accounts_players(:administrator) }
  end

  test "every action is denied by default, to everyone" do
    players.each do |role, player|
      policy = ApplicationPolicy.new(player, :anything)
      ACTIONS.each { |action| assert_not policy.public_send(action), "#{action} allowed to #{role}" }
    end
  end

  test "the role predicates follow the player's role" do
    expected = {
      visitor: { visitor?: true, player?: false, moderator?: false, administrator?: false },
      player: { visitor?: false, player?: true, moderator?: false, administrator?: false },
      moderator: { visitor?: false, player?: true, moderator?: true, administrator?: false },
      administrator: { visitor?: false, player?: true, moderator?: true, administrator?: true }
    }

    players.each do |role, player|
      policy = ApplicationPolicy.new(player, :anything)
      expected.fetch(role).each do |predicate, value|
        assert_equal value, policy.public_send(predicate), "#{predicate} for #{role}"
      end
    end
  end
end
