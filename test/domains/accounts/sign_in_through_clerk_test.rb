require "test_helper"
require_relative "../../support/clerk_fake"

class Accounts::SignInThroughClerkTest < ActiveSupport::TestCase
  include ClerkFake

  setup do
    ClerkFake.install(users: {
      "user_discord" => ClerkFake.api_user("user_discord", email: "gabe@example.com", accounts: [ { provider: "discord", uid: "d-1", email: "gabe@example.com" } ]),
      "user_other" => ClerkFake.api_user("user_other", email: "other@example.com", accounts: [ { provider: "discord", uid: "d-1" } ]),
      "user_code" => ClerkFake.api_user("user_code", email: "code@example.com"),
      "user_code_same_email" => ClerkFake.api_user("user_code_same_email", email: "gabe@example.com"),
      "user_second_address" => ClerkFake.api_user("user_second_address", email: "primary@example.com", accounts: [ { provider: "google", uid: "g-9", email: "gabe@example.com" } ]),
      "user_unverified" => ClerkFake.api_user("user_unverified", email: "ghost@example.com", email_verified: false),
      "user_both" => ClerkFake.api_user("user_both", accounts: [ { provider: "discord", uid: "d-1" }, { provider: "google", uid: "g-1" } ])
    })
  end

  def sign_in(user_id, **token) = Accounts::SignInThroughClerk.new.call(session_token: ClerkFake.session_token(user_id:, **token))

  def registered_events
    Rails.configuration.event_store.read.of_type(Accounts::PlayerRegistered).to_a
  end

  test "a new Discord user registers a player with a discord identity carrying the Clerk user id and the email hash" do
    player = sign_in("user_discord").value!

    identity = player.identities.sole
    assert_equal [ "discord", "d-1", "user_discord" ], [ identity.provider, identity.uid, identity.clerk_user_id ]
    assert_equal Accounts::EmailHash.call("gabe@example.com"), identity.email_hash
    assert_nil player.steam_id
    assert_not_nil player.reload.last_seen_at
    assert_equal 1, registered_events.size
  end

  test "the same user signs in the same player again, without a second registration" do
    first = sign_in("user_discord").value!

    assert_equal first, sign_in("user_discord").value!
    assert_equal 1, first.identities.count
    assert_equal 1, registered_events.size
  end

  test "a returning player signs in through another Clerk user holding the same Discord account" do
    first = sign_in("user_discord").value!

    assert_equal first, sign_in("user_other").value!
    assert_equal 1, first.identities.count
  end

  test "a player found through the Google account gets the Discord account added too" do
    google_only = Accounts::Player.create!(persona_name: "Gabe")
    google_only.identities.create!(provider: "google", uid: "g-1")

    player = sign_in("user_both").value!

    assert_equal google_only, player
    assert_equal [ [ "discord", "d-1" ], [ "google", "g-1" ] ], player.identities.order(:provider).pluck(:provider, :uid)
  end

  test "a user with both a Discord and a Google account gets both identities, then the missing one is added to a returning player" do
    discord_only = Accounts::Player.create!(persona_name: "Gabe")
    discord_only.identities.create!(provider: "discord", uid: "d-1")

    player = sign_in("user_both").value!

    assert_equal discord_only, player
    assert_equal [ [ "discord", "d-1" ], [ "google", "g-1" ] ], player.identities.order(:provider).pluck(:provider, :uid)
    assert_equal [ "user_both" ], player.identities.pluck(:clerk_user_id).uniq
  end

  test "a new user with two accounts registers one player holding both" do
    player = sign_in("user_both").value!

    assert_equal [ [ "discord", "d-1" ], [ "google", "g-1" ] ], player.identities.order(:provider).pluck(:provider, :uid)
  end

  test "an email code user is keyed on the Clerk user id" do
    player = sign_in("user_code").value!

    identity = player.identities.sole
    assert_equal [ "email", "user_code", "user_code" ], [ identity.provider, identity.uid, identity.clerk_user_id ]
    assert_equal Accounts::EmailHash.call("code@example.com"), identity.email_hash
    assert_equal player, sign_in("user_code").value!
  end

  test "an email already known through another identity by its hash is refused with the provider that holds it" do
    sign_in("user_discord").value!

    assert_equal Dry::Monads::Failure(:email_known_discord), sign_in("user_code_same_email")
  end

  test "an address of an external account other than the primary one is checked too" do
    sign_in("user_discord").value!

    assert_equal Dry::Monads::Failure(:email_known_discord), sign_in("user_second_address")
  end

  test "an unverified email gives no hash" do
    player = sign_in("user_unverified").value!

    assert_nil player.identities.sole.email_hash
  end

  test "a banned player is refused" do
    banned = accounts_players(:banned)
    banned.identities.create!(provider: "discord", uid: "d-1")

    assert_equal Dry::Monads::Failure(:banned), sign_in("user_discord")
  end

  test "an invalid token is invalid_session, a missing user clerk_unavailable" do
    assert_equal Dry::Monads::Failure(:invalid_session), sign_in("user_discord", azp: "https://evil.example")
    assert_equal Dry::Monads::Failure(:clerk_unavailable), sign_in("user_nobody")
    assert_equal 0, Accounts::Identity.through_clerk.count
  end

  test "an identity owned by another player is left alone when the user's other account is added" do
    owner = Accounts::Player.create!(persona_name: "Owner")
    owner.identities.create!(provider: "google", uid: "g-1")
    returning = Accounts::Player.create!(persona_name: "Gabe")
    returning.identities.create!(provider: "discord", uid: "d-1")

    assert_equal returning, sign_in("user_both").value!
    assert_equal [ "discord" ], returning.identities.pluck(:provider)
    assert_equal owner, Accounts::Identity.find_by(provider: "google", uid: "g-1").player
  end

  test "the failure codes have messages in both locales" do
    %i[invalid_session clerk_unavailable banned invalid_identity email_known_discord email_known_google email_known_email].each do |code|
      %i[en fr].each do |locale|
        assert_not_includes I18n.t(Accounts::SignInThroughClerk.failure_key(code), locale:, default: "missing"), "missing"
      end
    end
  end
end
