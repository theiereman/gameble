require "test_helper"

# Accounts::PublicProfile: the code naming a player without a persona
# name. Whose profile may be shown is Game::Visibility's question.
class Accounts::PublicProfileTest < ActiveSupport::TestCase
  test "the code is the first six Crockford base32 characters of the token's SHA-256" do
    token = "8fRbREJutTNEvhJdRHHihZ78"
    bits = Digest::SHA256.hexdigest(token)[0, 8].to_i(16).to_s(2).rjust(32, "0")[0, 30]
    expected = bits.scan(/.{5}/).map { "0123456789ABCDEFGHJKMNPQRSTVWXYZ"[it.to_i(2)] }.join

    assert_equal expected, Accounts::PublicProfile.code(token)
    assert_match(/\A[0-9A-HJKMNP-TV-Z]{6}\z/, Accounts::PublicProfile.code(token))
  end
end
