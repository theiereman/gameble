require "test_helper"

# Accounts::PublicProfile (CAP-8): whose profile may be shown, and the code
# naming a player without a persona name.
class Accounts::PublicProfileTest < ActiveSupport::TestCase
  test "a player's profile is visible to a visitor and to another player" do
    player = accounts_players(:player)

    assert Accounts::PublicProfile.visible?(player, viewer: nil)
    assert Accounts::PublicProfile.visible?(player, viewer: accounts_players(:moderator))
    assert Accounts::PublicProfile.visible?(player, viewer: player)
  end

  test "a banned player's profile, or no player, is not visible" do
    assert_not Accounts::PublicProfile.visible?(accounts_players(:banned), viewer: nil)
    assert_not Accounts::PublicProfile.visible?(accounts_players(:banned), viewer: accounts_players(:banned))
    assert_not Accounts::PublicProfile.visible?(nil, viewer: accounts_players(:player))
  end

  test "the code is the first six Crockford base32 characters of the token's SHA-256" do
    token = "8fRbREJutTNEvhJdRHHihZ78"
    bits = Digest::SHA256.hexdigest(token)[0, 8].to_i(16).to_s(2).rjust(32, "0")[0, 30]
    expected = bits.scan(/.{5}/).map { "0123456789ABCDEFGHJKMNPQRSTVWXYZ"[it.to_i(2)] }.join

    assert_equal expected, Accounts::PublicProfile.code(token)
    assert_match(/\A[0-9A-HJKMNP-TV-Z]{6}\z/, Accounts::PublicProfile.code(token))
  end

  test "the code is stable for a token and differs between tokens" do
    codes = accounts_players.map { Accounts::PublicProfile.code(it.token) }

    assert_equal codes, accounts_players.map { Accounts::PublicProfile.code(it.token) }
    assert_equal codes.size, codes.uniq.size
  end
end
