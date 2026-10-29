require "test_helper"

class Accounts::EmailHashTest < ActiveSupport::TestCase
  def hash_of(address) = Accounts::EmailHash.call(address)

  test "a blank address has no hash" do
    assert_nil hash_of(nil)
    assert_nil hash_of("  ")
  end

  test "the hash is 64 hex characters and never the address" do
    assert_match(/\A\h{64}\z/, hash_of("gabe@example.com"))
  end

  test "aliases of one mailbox give one hash" do
    assert_equal hash_of("gabenewell@gmail.com"), hash_of("Gabe.Newell+games@gmail.com")
    assert_equal hash_of("gabe@example.com"), hash_of("GABE+x@example.com")
  end

  test "different mailboxes give different hashes" do
    assert_not_equal hash_of("gabe@example.com"), hash_of("gaben@example.com")
  end

  test "the hash is keyed with the server secret" do
    plain = OpenSSL::Digest::SHA256.hexdigest("gabe@example.com")
    assert_not_equal plain, hash_of("gabe@example.com")
  end
end
