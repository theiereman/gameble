require "test_helper"
require_relative "../../support/clerk_fake"

class Accounts::AddClerkSignInTest < ActiveSupport::TestCase
  include ClerkFake

  setup do
    @player = accounts_players(:player)
    ClerkFake.install(users: {
      "user_google" => ClerkFake.api_user("user_google", email: "gabe@example.com", accounts: [ { provider: "google", uid: "g-1" } ]),
      "user_both" => ClerkFake.api_user("user_both", accounts: [ { provider: "discord", uid: "d-1" }, { provider: "google", uid: "g-1" } ]),
      "user_code" => ClerkFake.api_user("user_code", email: "code@example.com"),
      "user_unverified" => ClerkFake.api_user("user_unverified", email: "ghost@example.com", email_verified: false)
    })
  end

  def add(user_id, player: @player, **token) = Accounts::AddClerkSignIn.new.call(player:, session_token: ClerkFake.session_token(user_id:, **token))

  def added_events
    Rails.configuration.event_store.read.of_type(Accounts::IdentityAdded).to_a
  end

  test "every identity of the Clerk user joins the signed-in player, with the Clerk user id and an IdentityAdded each" do
    assert_equal @player, add("user_both").value!

    identities = @player.identities.where.not(provider: "steam").order(:provider)
    assert_equal [ [ "discord", "d-1", "user_both" ], [ "google", "g-1", "user_both" ] ], identities.pluck(:provider, :uid, :clerk_user_id)
    assert_equal %w[discord google], added_events.map { it.data[:provider] }.sort
  end

  test "the player keeps its other identities and no account is merged" do
    other = accounts_players(:moderator)

    add("user_google").value!

    assert_equal 1, @player.identities.where(provider: "steam").count
    assert_equal 1, other.identities.count
    assert_not_equal other, Accounts::Identity.find_by(provider: "google", uid: "g-1").player
  end

  test "an email code user joins as an email identity keyed on the Clerk user id, with the hash of its verified email" do
    add("user_code").value!

    identity = @player.identities.find_by!(provider: "email")
    assert_equal [ "user_code", "user_code", Accounts::EmailHash.call("code@example.com") ], [ identity.uid, identity.clerk_user_id, identity.email_hash ]
  end

  test "an unverified email gives no hash" do
    add("user_unverified").value!

    assert_nil @player.identities.find_by!(provider: "email").email_hash
  end

  test "an identity of another player is refused and nothing is added" do
    accounts_players(:moderator).identities.create!(provider: "google", uid: "g-1")

    assert_equal Dry::Monads::Failure(:identity_taken), add("user_both")
    assert_equal [ "steam" ], @player.identities.pluck(:provider)
    assert_empty added_events
  end

  test "adding again what the player holds already succeeds without a second row" do
    add("user_google").value!

    assert add("user_google").success?
    assert_equal 1, @player.identities.where(provider: "google").count
  end

  test "an email known on another player is refused with its provider" do
    other = accounts_players(:moderator)
    other.identities.create!(provider: "discord", uid: "d-other", email_hash: Accounts::EmailHash.call("gabe@example.com"))

    assert_equal Dry::Monads::Failure(:email_known_discord), add("user_google")
  end

  test "a removed or missing player is refused" do
    assert_equal Dry::Monads::Failure(:player_required), add("user_google", player: nil)
    assert_equal Dry::Monads::Failure(:player_required), add("user_google", player: accounts_players(:banned))
  end

  test "a bad session is invalid_session and an unreachable user clerk_unavailable" do
    assert_equal Dry::Monads::Failure(:invalid_session), add("user_google", azp: "https://evil.example")
    assert_equal Dry::Monads::Failure(:clerk_unavailable), add("user_nobody")
  end
end
