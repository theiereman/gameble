require "test_helper"

class Accounts::IdentityQueriesTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @identity = @player.identities.create!(provider: "google", uid: "g-1", email_hash: "abc")
  end

  test "IdentityByEmailHash finds the identity or nothing" do
    assert_equal @identity, Accounts::IdentityByEmailHash.call("abc")
    assert_nil Accounts::IdentityByEmailHash.call("other")
    assert_nil Accounts::IdentityByEmailHash.call(nil)
    assert_nil Accounts::IdentityByEmailHash.call("")
  end

  test "PlayerByIdentity finds the player or nothing" do
    assert_equal @player, Accounts::PlayerByIdentity.call(provider: "google", uid: "g-1")
    assert_nil Accounts::PlayerByIdentity.call(provider: "google", uid: "g-2")
    assert_nil Accounts::PlayerByIdentity.call(provider: "discord", uid: "g-1")
    assert_nil Accounts::PlayerByIdentity.call(provider: nil, uid: nil)
  end

  test "PlayerByIdentity ignores a deleted player" do
    @player.update_columns(deleted_at: Time.current, steam_id: nil)

    assert_nil Accounts::PlayerByIdentity.call(provider: "google", uid: "g-1")
  end
end
