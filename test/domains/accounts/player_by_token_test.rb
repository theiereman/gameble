require "test_helper"

# Accounts::PlayerByToken (CAP-8): a player by their public token.
class Accounts::PlayerByTokenTest < ActiveSupport::TestCase
  test "the player with that token, in one query" do
    player = accounts_players(:player)

    found = nil
    assert_queries_count(1) { found = Accounts::PlayerByToken.call(player.token) }
    assert_equal player, found
  end

  test "nil for an unknown token" do
    assert_nil Accounts::PlayerByToken.call("A" * 24)
  end

  [ nil, "", " ", 42, [ "x" ], { "token" => "x" } ].each do |token|
    test "no query for a token of #{token.inspect}" do
      assert_queries_count(0) { assert_nil Accounts::PlayerByToken.call(token) }
    end
  end
end
