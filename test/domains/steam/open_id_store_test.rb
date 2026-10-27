require "test_helper"

class Steam::OpenIdStoreTest < ActiveSupport::TestCase
  SERVER = "https://steamcommunity.com/openid/login".freeze

  setup do
    @cache = ActiveSupport::Cache::MemoryStore.new
    @store = Steam::OpenIdStore.new(cache: @cache)
  end

  test "a nonce is accepted once, then refused" do
    now = Time.now.to_i

    assert_equal true, @store.use_nonce(SERVER, now, "abc123")
    assert_equal false, @store.use_nonce(SERVER, now, "abc123")
  end

  test "a replay is refused by another store on the same cache, as in another process" do
    now = Time.now.to_i
    @store.use_nonce(SERVER, now, "abc123")

    assert_equal false, Steam::OpenIdStore.new(cache: @cache).use_nonce(SERVER, now, "abc123")
  end

  test "nonces differing by server, timestamp or salt are distinct" do
    now = Time.now.to_i
    @store.use_nonce(SERVER, now, "abc123")

    assert @store.use_nonce(SERVER, now, "abc124")
    assert @store.use_nonce(SERVER, now - 1, "abc123")
    assert @store.use_nonce("https://other.example/openid", now, "abc123")
  end

  test "a nonce outside the five-minute skew is refused" do
    now = Time.now.to_i

    assert_equal false, @store.use_nonce(SERVER, now - 5.minutes.to_i - 1, "old")
    assert_equal false, @store.use_nonce(SERVER, now + 5.minutes.to_i + 1, "future")
    assert @store.use_nonce(SERVER, now - 5.minutes.to_i + 2, "recent")
  end

  test "a future-dated nonce is still refused on the last second it would be accepted" do
    now = Time.now.to_i
    timestamp = now + 5.minutes.to_i
    assert @store.use_nonce(SERVER, timestamp, "edge")

    travel_to Time.at(timestamp + 5.minutes.to_i) do
      assert_equal false, @store.use_nonce(SERVER, timestamp, "edge")
    end
  end

  test "ruby-openid uses the same five-minute skew" do
    assert_equal 5.minutes.to_i, OpenID::Nonce.skew
  end

  test "associations are not kept" do
    association = OpenID::Association.from_expires_in(3600, "handle", "secret", "HMAC-SHA1")
    @store.store_association(SERVER, association)

    assert_nil @store.get_association(SERVER)
    assert_nil @store.get_association(SERVER, "handle")
    assert_equal false, @store.remove_association(SERVER, "handle")
  end

  test "the sign-in request opens no association with a stateless store" do
    manager = OpenID::Consumer::AssociationManager.new(@store, SERVER)
    manager.define_singleton_method(:negotiate_association) { flunk "an association was requested" }

    assert_nil manager.get_association
  end

  test "ruby-openid verifies TLS certificates against the system CA bundle" do
    assert_equal OpenSSL::X509::DEFAULT_CERT_FILE, OpenID.fetcher.ca_file
  end
end
