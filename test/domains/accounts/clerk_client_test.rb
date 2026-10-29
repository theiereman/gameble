require "test_helper"
require_relative "../../support/clerk_fake"

class Accounts::ClerkClientTest < ActiveSupport::TestCase
  include ClerkFake

  setup do
    @fake = ClerkFake.install(users: {
      "user_1" => ClerkFake.api_user("user_1", email: "gabe@example.com", accounts: [
        { provider: "discord", uid: "d-1", email: "gabe@example.com" },
        { provider: "google", uid: "g-1", email: "gabe@example.com", verified: false },
        { provider: "github", uid: "gh-1" }
      ])
    })
  end

  def client = Accounts::ClerkClient.new

  test "a token signed by the instance key, from an authorized origin, gives its claims" do
    claims = client.verify_session(ClerkFake.session_token(user_id: "user_1")).value!

    assert_equal "user_1", claims["sub"]
  end

  test "an authorized party is the public origin, and the local origins outside production" do
    parties = Accounts::ClerkClient.authorized_parties

    assert_includes parties, "http://localhost:3000"
    assert_includes parties, "http://127.0.0.1:3000"
  end

  test "a token from another issuer is refused" do
    token = ClerkFake.session_token(user_id: "user_1", issuer: "https://evil.clerk.accounts.dev")

    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(token)
  end

  test "a token from an origin that is not authorized is refused" do
    token = ClerkFake.session_token(user_id: "user_1", azp: "https://evil.example")

    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(token)
  end

  test "an expired token is refused, a token expired within the leeway is not" do
    expired = ClerkFake.session_token(user_id: "user_1", issued_at: 2.minutes.ago)
    just_expired = ClerkFake.session_token(user_id: "user_1", issued_at: 62.seconds.ago)

    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(expired)
    assert client.verify_session(just_expired).success?
  end

  test "a token not valid yet is refused" do
    token = ClerkFake.session_token(user_id: "user_1", issued_at: 1.minute.from_now)

    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(token)
  end

  test "a token signed by another key is refused" do
    forged = JWT.encode({ sub: "user_1", iss: "https://#{Rails.configuration.x.clerk.frontend_api}", azp: ClerkFake::AZP, exp: 1.minute.from_now.to_i },
      OpenSSL::PKey::RSA.generate(2048), "RS256", { kid: ClerkFake::KID })

    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(forged)
  end

  test "garbage and an unsigned token are refused" do
    unsigned = JWT.encode({ sub: "user_1", exp: 1.minute.from_now.to_i }, nil, "none")

    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session("not a token")
    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(nil)
    assert_equal Dry::Monads::Failure(:invalid_session), client.verify_session(unsigned)
  end

  test "an unknown key id refetches the key list once, then refuses" do
    client.verify_session(ClerkFake.session_token(user_id: "user_1"))
    assert_equal 1, @fake.jwks_calls

    result = client.verify_session(ClerkFake.session_token(user_id: "user_1", kid: "rotated"))

    assert_equal Dry::Monads::Failure(:invalid_session), result
    assert_equal 2, @fake.jwks_calls
  end

  test "the key list is cached for an hour" do
    token = ClerkFake.session_token(user_id: "user_1")
    client.verify_session(token)
    client.verify_session(token)
    assert_equal 1, @fake.jwks_calls

    travel_to(61.minutes.from_now) { client.verify_session(ClerkFake.session_token(user_id: "user_1")) }

    assert_equal 2, @fake.jwks_calls
  end

  test "an unreachable key list is clerk_unavailable" do
    @fake.unavailable = true

    assert_equal Dry::Monads::Failure(:clerk_unavailable), client.verify_session(ClerkFake.session_token(user_id: "user_1"))
  end

  test "a user keeps the Discord and Google accounts, drops other providers, and reads the primary verified email" do
    user = client.user("user_1").value!

    assert_equal "user_1", user.id
    assert_equal [
      Accounts::ClerkUser::ExternalAccount.new(provider: "discord", uid: "d-1", email: "gabe@example.com", verified: true),
      Accounts::ClerkUser::ExternalAccount.new(provider: "google", uid: "g-1", email: "gabe@example.com", verified: false)
    ], user.external_accounts
    assert_equal "gabe@example.com", user.primary_verified_email
  end

  test "an unverified primary email is no verified email" do
    @fake.users["user_2"] = ClerkFake.api_user("user_2", email: "x@example.com", email_verified: false)

    user = client.user("user_2").value!

    assert_nil user.primary_verified_email
    assert_empty user.external_accounts
  end

  test "a missing user, or an unreachable Clerk, is clerk_unavailable" do
    assert_equal Dry::Monads::Failure(:clerk_unavailable), client.user("user_unknown")

    @fake.unavailable = true
    assert_equal Dry::Monads::Failure(:clerk_unavailable), client.user("user_1")
    assert_equal Dry::Monads::Failure(:clerk_unavailable), client.delete_user("user_1")
  end

  test "deleting a user asks Clerk to delete it" do
    assert client.delete_user("user_1").success?
    assert_equal [ "user_1" ], @fake.deleted
  end

  test "it is configured with an adapter or a secret key" do
    assert Accounts::ClerkClient.configured?

    ClerkFake.uninstall
    key = Rails.configuration.x.clerk.secret_key
    Rails.configuration.x.clerk.secret_key = nil
    assert_not Accounts::ClerkClient.configured?
  ensure
    Rails.configuration.x.clerk.secret_key = key
  end
end

class Accounts::ClerkClientHttpAdapterTest < ActiveSupport::TestCase
  SECRET = "sk_test_0123456789abcdefSECRET".freeze

  setup do
    @was = [ Accounts::ClerkClient::HttpAdapter.connection_adapter, Accounts::ClerkClient::HttpAdapter.retry_interval ]
    @stubs = Faraday::Adapter::Test::Stubs.new
    Accounts::ClerkClient::HttpAdapter.connection_adapter = [ :test, @stubs ]
    Accounts::ClerkClient::HttpAdapter.retry_interval = 0
  end

  teardown { Accounts::ClerkClient::HttpAdapter.connection_adapter, Accounts::ClerkClient::HttpAdapter.retry_interval = @was }

  def adapter = Accounts::ClerkClient::HttpAdapter.new(secret_key: SECRET)

  def json(body, status = 200) = [ status, { "Content-Type" => "application/json" }, body.to_json ]

  test "it fetches the key list with the secret key as a bearer token" do
    seen = nil
    @stubs.get("/v1/jwks") { |env| seen = env.request_headers["Authorization"] and json({ "keys" => [ { "kid" => "k" } ] }) }

    assert_equal [ { "kid" => "k" } ], adapter.jwks
    assert_equal "Bearer #{SECRET}", seen
  end

  test "a missing user answers nil, and a missing user to delete is deleted already" do
    @stubs.get("/v1/users/user_1") { json({}, 404) }
    @stubs.delete("/v1/users/user_1") { json({}, 404) }

    assert_nil adapter.user("user_1")
    assert adapter.delete_user("user_1")
  end

  test "a server error is retried, then raised" do
    calls = 0
    @stubs.delete("/v1/users/user_1") { calls += 1 and json({}, 503) }

    assert_raises(Accounts::ClerkClient::Error) { adapter.delete_user("user_1") }
    assert_equal 4, calls
  end

  test "a rate limit is retried" do
    answers = [ json({}, 429), json({ "deleted" => true }) ]
    @stubs.delete("/v1/users/user_1") { answers.shift }

    assert adapter.delete_user("user_1")
  end

  test "the secret key never appears in an error, nor in the adapter's inspection" do
    @stubs.get("/v1/users/user_1") { raise Faraday::ConnectionFailed, "failed to connect with #{SECRET} and #{CGI.escape(SECRET)}" }

    error = assert_raises(Accounts::ClerkClient::Error) { adapter.user("user_1") }

    assert_not_includes error.message, SECRET
    assert_includes error.message, Accounts::ClerkClient::HttpAdapter::REDACTED
    assert_not_includes adapter.inspect, SECRET
  end

  test "an unauthorized answer raises an error without the key" do
    @stubs.get("/v1/jwks") { json({ "errors" => [ SECRET ] }, 401) }

    error = assert_raises(Accounts::ClerkClient::Error) { adapter.jwks }

    assert_not_includes error.message, SECRET
  end

  test "without a secret key it raises before any request" do
    assert_raises(Accounts::ClerkClient::Error) { Accounts::ClerkClient::HttpAdapter.new(secret_key: nil).jwks }
  end
end
