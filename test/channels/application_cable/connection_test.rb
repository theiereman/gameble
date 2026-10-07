require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "a signed-in player is identified from the session" do
    player = accounts_players(:player)

    connect session: { player_id: player.id }

    assert_equal player, connection.current_player
  end

  test "a visitor connects as nobody" do
    connect

    assert_nil connection.current_player
  end

  test "a banned player cannot connect" do
    assert_reject_connection { connect session: { player_id: accounts_players(:banned).id } }
  end

  test "a deleted account cannot connect" do
    player = accounts_players(:player)
    Accounts::DeletePlayer.new.call(player:).value!

    assert_reject_connection { connect session: { player_id: player.id } }
  end

  test "an id that names nobody connects as nobody" do
    connect session: { player_id: 0 }

    assert_nil connection.current_player
  end
end
