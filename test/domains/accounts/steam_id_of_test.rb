require "test_helper"

# The one read of a player's Steam id: the uid of their Steam identity.
class Accounts::SteamIdOfTest < ActiveSupport::TestCase
  test "a player signed in with Steam has the uid of their Steam identity" do
    player = accounts_players(:player)
    player.identities.create!(provider: "google", uid: "g-1")

    assert_equal "76561197960287001", Accounts::SteamIdOf.call(player)
  end

  test "a player without a Steam identity, an unsaved one or none has no Steam id" do
    player = accounts_players(:player)
    player.identities.where(provider: "steam").delete_all
    player.identities.create!(provider: "discord", uid: "d-1")

    assert_nil Accounts::SteamIdOf.call(player)
    assert_nil Accounts::SteamIdOf.call(Accounts::Player.new)
    assert_nil Accounts::SteamIdOf.call(nil)
  end
end
