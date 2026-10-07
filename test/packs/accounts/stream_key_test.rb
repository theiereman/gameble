require "test_helper"

class Accounts::StreamKeyTest < ActiveSupport::TestCase
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  test "every player has a key of their own, a new one included" do
    created = Accounts::Player.create!(steam_id: "76561197960287123")
    keys = Accounts::Player.pluck(:stream_key)

    assert_match UUID, created.stream_key
    assert_equal created.stream_key, created.reload.stream_key
    assert keys.all? { it.match?(UUID) }
    assert_equal keys.size, keys.uniq.size
  end

  test "a ban changes the key, in the same write" do
    player = accounts_players(:player)
    before = player.stream_key

    player.update!(banned_at: Time.current)

    assert_not_equal before, player.reload.stream_key
    assert_match UUID, player.stream_key
  end

  test "deleting the account changes the key" do
    player = accounts_players(:player)
    before = player.stream_key

    assert Accounts::DeletePlayer.new.call(player:).success?

    assert_not_equal before, player.reload.stream_key
  end

  test "other writes keep the key, lifting a ban included" do
    player = accounts_players(:player)
    before = player.stream_key

    player.update!(persona_name: "Hugo", reduced_motion: true, last_seen_at: Time.current)
    assert_equal before, player.reload.stream_key

    banned = accounts_players(:banned)
    key = banned.stream_key
    banned.update!(banned_at: nil)
    assert_equal key, banned.reload.stream_key
  end
end
