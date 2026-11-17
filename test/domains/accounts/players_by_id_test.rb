require "test_helper"

# Accounts::PlayersById: the players of several ids, in one query.
class Accounts::PlayersByIdTest < ActiveSupport::TestCase
  test "the players with those ids, in one query" do
    wanted = [ accounts_players(:player), accounts_players(:moderator) ]

    found = nil
    assert_queries_count(1) { found = Accounts::PlayersById.call(wanted.map(&:id) + [ 0 ]) }
    assert_equal wanted.sort_by(&:id), found.sort_by(&:id)
  end
end
